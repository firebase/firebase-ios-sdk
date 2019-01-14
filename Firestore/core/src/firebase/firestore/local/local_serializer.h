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

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"
#include "Firestore/Protos/nanopb/firestore/local/target.nanopb.h"
#include "Firestore/core/src/firebase/firestore/local/query_data.h"
#include "Firestore/core/src/firebase/firestore/model/document.h"
#include "Firestore/core/src/firebase/firestore/model/maybe_document.h"
#include "Firestore/core/src/firebase/firestore/model/no_document.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"
#include "Firestore/core/src/firebase/firestore/nanopb/reader.h"
#include "Firestore/core/src/firebase/firestore/nanopb/writer.h"
#include "Firestore/core/src/firebase/firestore/remote/serializer.h"
#include "Firestore/core/src/firebase/firestore/util/status.h"

namespace firebase {
namespace firestore {
namespace local {

/**
 * @brief Serializer for values stored in the LocalStore.
 *
 * Note that local::LocalSerializer currently delegates to the
 * remote::Serializer (for the Firestore v1 RPC protocol) to save implementation
 * time and code duplication. We'll need to revisit this when the RPC protocol
 * we use diverges from local storage.
 */
class LocalSerializer {
 public:
  explicit LocalSerializer(const remote::Serializer& rpc_serializer)
      : rpc_serializer_(rpc_serializer) {
  }

  /**
   * Release memory allocated by the Encode* methods that return protos.
   *
   * This essentially wraps calls to nanopb's pb_release() method.
   */
  static void FreeNanopbMessage(const pb_field_t fields[], void* dest_struct) {
    remote::Serializer::FreeNanopbMessage(fields, dest_struct);
  }

  /**
   * @brief Encodes a MaybeDocument model to the equivalent nanopb proto for
   * local storage.
   *
   * Any errors that occur during encoding are fatal.
   */
  firestore_client_MaybeDocument EncodeMaybeDocument(
      const model::MaybeDocument& maybe_doc) const;

  /**
   * @brief Decodes nanopb proto representing a MaybeDocument proto to the
   * equivalent model.
   *
   * Check reader->status() to determine if an error occurred while decoding.
   *
   * @param reader The Reader object. Used only for error handling.
   * @return The model equivalent of the bytes or nullopt if an error occurred.
   * @post (reader->status().ok() && result) ||
   * (!reader->status().ok() && !result)
   */
  std::unique_ptr<model::MaybeDocument> DecodeMaybeDocument(
      nanopb::Reader* reader,
      const firestore_client_MaybeDocument& proto) const;

  /**
   * @brief Encodes a QueryData to the equivalent nanopb proto, representing a
   * ::firestore::proto::Target, for local storage.
   *
   * Any errors that occur during encoding are fatal.
   */
  firestore_client_Target EncodeQueryData(const QueryData& query_data) const;

  /**
   * @brief Decodes nanopb proto representing a ::firestore::proto::Target proto
   * to the equivalent QueryData.
   *
   * Check reader->status() to determine if an error occurred while decoding.
   *
   * @param reader The Reader object. Used only for error handling.
   * @return The QueryData equivalent of the bytes. On error, the return value
   * is unspecified.
   */
  QueryData DecodeQueryData(nanopb::Reader* reader,
                            const firestore_client_Target& proto) const;

 private:
  /**
   * Encodes a Document for local storage. This differs from the v1 RPC
   * serializer for Documents in that it preserves the updateTime, which is
   * considered an output only value by the server.
   */
  google_firestore_v1_Document EncodeDocument(const model::Document& doc) const;

  firestore_client_NoDocument EncodeNoDocument(
      const model::NoDocument& no_doc) const;

  std::unique_ptr<model::NoDocument> DecodeNoDocument(
      nanopb::Reader* reader, const firestore_client_NoDocument& proto) const;

  const remote::Serializer& rpc_serializer_;
};

}  // namespace local
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_LOCAL_LOCAL_SERIALIZER_H_
