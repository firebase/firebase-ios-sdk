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
#include "absl/strings/numbers.h"

namespace firebase {
namespace firestore{
namespace bundle {

using nlohmann::json;

namespace {

json Parse(absl::string_view s) {
  return json::parse(s.begin(), s.end(), /*callback=*/nullptr, /*allow_exception=*/false);
}

} // namespace

BundleReader::BundleReader(BundleSerializer serializer, std::unique_ptr<std::istream> input):
      serializer_(std::move(serializer)),
      input_(std::move(input)){
}

std::unique_ptr<BundleElement> BundleReader::ReadNextElement() {
  auto length_prefix_size = ReadLengthPrefixSize();
  if(!length_prefix_size.has_value()) {
    return nullptr;
  }

  absl::string_view length_prefix(buffer_.data(), length_prefix_size.value());
  size_t prefix_value;
  auto ok = absl::SimpleAtoi<size_t>(length_prefix, &prefix_value);
  if(!ok) {
    // TODO
    json_reader_.Fail("Fail");
    return nullptr;
  }

  buffer_.erase(0, length_prefix_size.value());
  absl::string_view json = ReadJsonString(prefix_value);

  bytes_read_ += length_prefix_size.value() + json.size();
  auto result = DecodeBundleElement(json);
  buffer_.erase(0, json.size());

  return result;
}

absl::optional<size_t> BundleReader::ReadLengthPrefixSize() {
  size_t next_open_bracket_pos;

  // Pull in more data to internal buffer until we can find a '{', breaks
  // when either '{' is found or no more data can be pulled.
  while ((next_open_bracket_pos = buffer_.find_first_of('{')) == std::string::npos) {
    if (!PullMoreData()) {
      break;
    }
  }

  // We broke out because underlying stream is closed, and there happens to be no
  // more data to process.
  if(buffer_.empty()) {
    return absl::nullopt;
  }

  // We broke out of the loop because underlying stream is closed, but still cannot find an
  // open bracket.
  if(next_open_bracket_pos == std::string::npos) {
    // TODO
    json_reader_.Fail("Reached the end of bundle when a length string is expected.");
    return absl::nullopt;
  }

  return absl::make_optional(next_open_bracket_pos);
}

absl::string_view BundleReader::ReadJsonString(size_t length) {
  while (buffer_.size() < length) {
    if(PullMoreData()) {
      break;
    }
  }

  if(buffer_.size() < length) {
    // TODO
    json_reader_.Fail("");
    return {};
  }

  return {buffer_.data(), length};
}

std::unique_ptr<BundleElement> BundleReader::DecodeBundleElement(absl::string_view json) {
  auto json_object = Parse(json);
  if (json_object.is_discarded()) {
    json_reader_.Fail("Failed to parse string into json: ");
    return nullptr;
  }

  if(json_object.contains("metadata")) {
    return absl::make_unique<BundleMetadata>(
            serializer_.DecodeBundleMetadata(json_reader_, json_object));
  } else if (json_object.contains("namedQuery")) {
    return absl::make_unique<NamedQuery>(
        serializer_.DecodeNamedQuery(json_reader_, json_object));
  } else if (json_object.contains("documentMetadata")) {
    return absl::make_unique<BundledDocumentMetadata>(
        serializer_.DecodeDocumentMetadata(json_reader_, json_object));
  } else if (json_object.contains("document")) {
    return absl::make_unique<BundleDocument>(
        serializer_.DecodeDocument(json_reader_, json_object));
  } else {
    json_reader_.Fail("Fail");
    return nullptr;
  }
}

bool BundleReader::PullMoreData() {
  char data[10240];
  input_->readsome(data, 10240);
  // TODO: check error
  buffer_.append(data);
  return true;
}

} // namespace bundle
} // namespace firestore
} // namespace firebase
