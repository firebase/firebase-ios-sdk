/*
 * Copyright 2021 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "Firestore/core/src/bundle/bundle_reader.h"

#include <algorithm>

#include "absl/strings/numbers.h"

namespace firebase {
namespace firestore {
namespace bundle {

using nlohmann::json;

namespace {

json Parse(absl::string_view s) {
  return json::parse(s.begin(), s.end(), /*callback=*/nullptr,
                     /*allow_exception=*/false);
}

}  // namespace

BundleReader::BundleReader(BundleSerializer serializer,
                           std::unique_ptr<std::istream> input)
    : serializer_(std::move(serializer)), input_(std::move(input)) {
}

BundleMetadata BundleReader::GetBundleMetadata() {
  if (metadata_loaded_) {
    return metadata_;
  }

  std::unique_ptr<BundleElement> element = ReadNextElement();
  if (!element || element->ElementType() != BundleElementType::Metadata) {
    Fail("Failed to get bundle metadata");
    return {};
  }

  metadata_loaded_ = true;
  metadata_ = dynamic_cast<BundleMetadata&>(*element);
  return metadata_;
}

std::unique_ptr<BundleElement> BundleReader::GetNextElement() {
  // Makes sure metadata is read before proceeding. The metadata element is the
  // first element in the bundle stream.
  GetBundleMetadata();
  return ReadNextElement();
}

std::unique_ptr<BundleElement> BundleReader::ReadNextElement() {
  auto length_prefix = ReadLengthPrefix();
  if (!length_prefix.has_value()) {
    return nullptr;
  }

  size_t prefix_value;
  auto ok = absl::SimpleAtoi<size_t>(length_prefix.value(), &prefix_value);
  if (!ok) {
    Fail("prefix string is not a valid number");
    return nullptr;
  }

  buffer_.clear();
  ReadJsonToBuffer(prefix_value);

  // metadata's size does not count in `bytes_read_`.
  if (metadata_loaded_) {
    bytes_read_ += length_prefix.value().size() + buffer_.size();
  }
  auto result = DecodeBundleElementFromBuffer();
  reader_status_.Update(json_reader_.status());

  return result;
}

absl::optional<std::string> BundleReader::ReadLengthPrefix() {
  std::string result;
  while (!(input_->fail())) {
    // Fill `length_chars` until a `{` is found. 10 should be more than enough
    // to represent a length. Also appending `\0` is taken cared of by `get`.
    char length_chars[10];
    input_->get(length_chars, 10, '{');

    // We broke out because underlying stream is closed, and there happens to be
    // no more data to process.
    if (input_->gcount() == 0 && input_->eof()) {
      return absl::nullopt;
    }

    result.append(length_chars);

    // We need a way to determine if `get` returned because a `{` is hit, or
    // because we filled `length_chars`.
    if (input_->gcount() < 9) {
      break;
    }
  }

  if (input_->fail()) {
    Fail("Reached the end of bundle when a length string is expected.");
    return absl::nullopt;
  }

  return absl::make_optional(std::move(result));
}

void BundleReader::ReadJsonToBuffer(size_t length) {
  while (buffer_.size() < length) {
    if (!PullMoreData(length - buffer_.size())) {
      break;
    }
  }

  if (buffer_.size() < length) {
    Fail("Available input string is smaller than what length prefix indicates");
  }
}

bool BundleReader::PullMoreData(uint32_t required_size) {
  if (input_->fail() || input_->eof()) {
    return false;
  }

  // Read at most 1024 bytes every time, to avoid allocating a huge buffer when
  // corruption leads to large `required_size`.
  auto size = std::min(1024u, required_size);
  char data[size + 1];
  input_->read(data, size);
  // `read` does not do this for us, unlike `get`.
  data[input_->gcount()] = '\0';
  buffer_.append(data);
  return true;
}

std::unique_ptr<BundleElement> BundleReader::DecodeBundleElementFromBuffer() {
  auto json_object = Parse(buffer_);
  if (json_object.is_discarded()) {
    Fail("Failed to parse string into json: ");
    return nullptr;
  }

  if (json_object.contains("metadata")) {
    return absl::make_unique<BundleMetadata>(serializer_.DecodeBundleMetadata(
        json_reader_, json_object.at("metadata")));
  } else if (json_object.contains("namedQuery")) {
    auto q = serializer_.DecodeNamedQuery(json_reader_,
                                          json_object.at("namedQuery"));
    return absl::make_unique<NamedQuery>(std::move(q));
  } else if (json_object.contains("documentMetadata")) {
    return absl::make_unique<BundledDocumentMetadata>(
        serializer_.DecodeDocumentMetadata(json_reader_,
                                           json_object.at("documentMetadata")));
  } else if (json_object.contains("document")) {
    return absl::make_unique<BundleDocument>(
        serializer_.DecodeDocument(json_reader_, json_object.at("document")));
  } else {
    Fail("Unrecognized BundleElement");
    return nullptr;
  }
}

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase
