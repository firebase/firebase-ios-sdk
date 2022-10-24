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

#ifndef FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_SERIALIZER_H_
#define FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_SERIALIZER_H_

#include <string>
#include <utility>
#include <vector>

#include "Firestore/core/src/bundle/bundle_document.h"
#include "Firestore/core/src/bundle/bundle_metadata.h"
#include "Firestore/core/src/bundle/bundled_document_metadata.h"
#include "Firestore/core/src/bundle/named_query.h"
#include "Firestore/core/src/core/core_fwd.h"
#include "Firestore/core/src/core/filter.h"
#include "Firestore/core/src/model/resource_path.h"
#include "Firestore/core/src/model/snapshot_version.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/json_reader.h"
#include "Firestore/core/src/util/read_context.h"
#include "Firestore/third_party/nlohmann_json/json.hpp"

namespace firebase {
namespace firestore {

namespace bundle {

/** A JSON serializer to deserialize Firestore Bundles. */
class BundleSerializer {
 public:
  explicit BundleSerializer(remote::Serializer serializer)
      : rpc_serializer_(std::move(serializer)) {
  }
  BundleMetadata DecodeBundleMetadata(util::JsonReader& reader,
                                      const nlohmann::json& metadata) const;

  NamedQuery DecodeNamedQuery(util::JsonReader& reader,
                              const nlohmann::json& named_query) const;

  BundledDocumentMetadata DecodeDocumentMetadata(
      util::JsonReader& reader, const nlohmann::json& document_metadata) const;

  BundleDocument DecodeDocument(util::JsonReader& reader,
                                const nlohmann::json& document) const;

 private:
  BundledQuery DecodeBundledQuery(util::JsonReader& reader,
                                  const nlohmann::json& query) const;
  std::vector<core::Filter> DecodeWhere(util::JsonReader& reader,
                                        const nlohmann::json& query) const;
  core::Filter DecodeFieldFilter(util::JsonReader& reader,
                                 const nlohmann::json& filter) const;
  std::vector<core::Filter> DecodeCompositeFilter(
      util::JsonReader& reader, const nlohmann::json& filter) const;
  nanopb::Message<google_firestore_v1_Value> DecodeValue(
      util::JsonReader& reader, const nlohmann::json& value) const;

  core::Bound DecodeStartAtBound(util::JsonReader& reader,
                                 const nlohmann::json& query) const;
  core::Bound DecodeEndAtBound(util::JsonReader& reader,
                               const nlohmann::json& query) const;

  // Decodes a `bound` JSON and returns a pair whose first element is the value
  // of the `before` JSON field, and second element is the array value
  // representing the bounded field values.
  std::pair<bool, nanopb::SharedMessage<google_firestore_v1_ArrayValue>>
  DecodeBoundFields(util::JsonReader& reader,
                    const nlohmann::json& bound_json) const;

  model::ResourcePath DecodeName(util::JsonReader& reader,
                                 const nlohmann::json& name) const;
  nanopb::Message<google_firestore_v1_ArrayValue> DecodeArrayValue(
      util::JsonReader& reader, const nlohmann::json& array_json) const;
  nanopb::Message<google_firestore_v1_MapValue> DecodeMapValue(
      util::JsonReader& reader, const nlohmann::json& map_json) const;
  pb_bytes_array_t* DecodeReferenceValue(util::JsonReader& reader,
                                         const std::string& ref_string) const;

  remote::Serializer rpc_serializer_;
};

}  // namespace bundle
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_BUNDLE_BUNDLE_SERIALIZER_H_
