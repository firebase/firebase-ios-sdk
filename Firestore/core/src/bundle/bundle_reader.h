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
#ifndef FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_READER_H_
#define FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_READER_H_

#include <istream>
#include <memory>

#include "Firestore/core/src/bundle/bundle_metadata.h"
#include "Firestore/core/src/bundle/bundle_serializer.h"

namespace firebase {
namespace firestore {
namespace bundle {

/**
 * Reads the length-prefixed JSON stream for Bundles.
 *
 * The class takes a bundle stream and presents abstractions to read bundled
 * elements out of the underlying content.
 */
class BundleReader {
 public:
  BundleReader(BundleSerializer serializer, std::unique_ptr<std::istream> input);

  /** Returns the metadata element from the bundle. */
  BundleMetadata GetBundleMetadata();

  /**
   * Returns the next element from the bundle. Metadata elements can be accessed
   * by `GetBundleMetadata`, they are not returned from this method.
   */
  std::unique_ptr<BundleElement> GetNextElement();

  int64_t BytesRead() const {
    return bytes_read_;
  }

 private:
  /**
   * Reads from the head of internal buffer, Pulls more data from underlying
   * stream until a complete element is found (including the prefixed length and
   * the JSON string).
   *
   * Once a complete element is read, it is dropped from internal buffer.
   *
   * Returns either the bundled element, or null if we have reached the end of
   * the stream.
   */
  std::unique_ptr<BundleElement> ReadNextElement();

  absl::optional<size_t> ReadLengthPrefixSize();
  absl::string_view ReadJsonString(size_t length);
  bool PullMoreData();
  std::unique_ptr<BundleElement> DecodeBundleElement(absl::string_view json);

  BundleSerializer serializer_;
  JsonReader json_reader_;
  std::unique_ptr<std::istream> input_;
  BundleMetadata metadata_;
  bool metadata_loaded_;
  int64_t bytes_read_ = 0;
  std::string buffer_;
};

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_READER_H_
