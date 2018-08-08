/*
 * Copyright 2018 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LOCAL_SERIALIZER_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LOCAL_SERIALIZER_H_

#include <memory>
#include <vector>

#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"
#include "absl/types/optional.h"

namespace firebase {
namespace firestore {
namespace local {

/**
 * @brief Serializer for values stored in the LocalStore.
 *
 * Note that local::LocalSerializer currently delegates to the
 * remote::Serializer (for the Firestore v1beta1 RPC protocol) to save
 * implementation time and code duplication. We'll need to revisit this when the
 * RPC protocol we use diverges from local storage.
 */
class LocalSerializer {
 public:
  explicit LocalSerializer(const remote::Serializer& rpc_serializer)
      : rpc_serializer_(rpc_serializer) {
  }

  /**
   * @brief Encodes a MaybeDocument model to the equivalent bytes for local
   * storage.
   *
   * Any errors that occur during encoding are fatal.
   *
   * @param writer The serialized output will be written to the provided writer.
   * @param maybe_doc the model to convert.
   */
  void EncodeMaybeDocument(nanopb::Writer* writer,
                           const model::MaybeDocument& maybe_doc) const;

  /**
   * @brief Decodes bytes representing a MaybeDocument proto to the equivalent
   * model.
   *
   * Check reader->status() to determine if an error occured while decoding.
   *
   * @param reader The reader object containing the bytes to convert. It's
   * assumed that exactly all of the bytes will be used by this conversion.
   * @return The model equivalent of the bytes or nullopt if an error occurred.
   * @post (reader->status().ok() && result) ||
   * (!reader->status().ok() && !result)
   */
  std::unique_ptr<model::MaybeDocument> DecodeMaybeDocument(
      nanopb::Reader* reader) const;

  /**
   * @brief Encodes a QueryData to the equivalent bytes, representing a
   * ::firestore::proto::Target, for local storage.
   *
   * Any errors that occur during encoding are fatal.
   *
   * @param writer The serialized output will be written to the provided writer.
   */
  void EncodeQueryData(nanopb::Writer* writer,
                       const QueryData& query_data) const;

  /**
   * @brief Decodes bytes representing a ::firestore::proto::Target proto to the
   * equivalent QueryData.
   *
   * Check writer->status() to determine if an error occured while decoding.
   *
   * @param reader The reader object containing the bytes to convert. It's
   * assumed that exactly all of the bytes will be used by this conversion.
   * @return The QueryData equivalent of the bytes or nullopt if an error
   * occurred.
   * @post (reader->status().ok() && result.has_value()) ||
   * (!reader->status().ok() && !result.has_value())
   */
  absl::optional<QueryData> DecodeQueryData(nanopb::Reader* reader) const;

 private:
  /**
   * Encodes a Document for local storage. This differs from the v1beta1 RPC
   * serializer for Documents in that it preserves the updateTime, which is
   * considered an output only value by the server.
   */
  void EncodeDocument(nanopb::Writer* writer, const model::Document& doc) const;

  void EncodeNoDocument(nanopb::Writer* writer,
                        const model::NoDocument& no_doc) const;

  std::unique_ptr<model::NoDocument> DecodeNoDocument(
      nanopb::Reader* reader) const;

  const remote::Serializer& rpc_serializer_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LOCAL_SERIALIZER_H_
