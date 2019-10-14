/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_FIELDS_MAP_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_FIELDS_MAP_H_

#include "Firestore/Protos/nanopb/firestore/local/maybe_document.nanopb.h"
#include "Firestore/Protos/nanopb/firestore/local/mutation.nanopb.h"
#include "Firestore/Protos/nanopb/firestore/local/target.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"
#include "Firestore/Protos/nanopb/google/firestore/v1/firestore.nanopb.h"
#include "Firestore/Protos/nanopb/google/type/latlng.nanopb.h"

namespace firebase {
namespace firestore {
namespace nanopb {

template <typename T>
const pb_field_t* GetNanopbFields() = delete;

template <>
inline const pb_field_t* GetNanopbFields<firestore_client_MaybeDocument>() {
  return firestore_client_MaybeDocument_fields;
}

template <>
inline const pb_field_t* GetNanopbFields<firestore_client_MutationQueue>() {
  return firestore_client_MutationQueue_fields;
}

template <>
inline const pb_field_t* GetNanopbFields<firestore_client_Target>() {
  return firestore_client_Target_fields;
}

template <>
inline const pb_field_t* GetNanopbFields<firestore_client_TargetGlobal>() {
  return firestore_client_TargetGlobal_fields;
}

template <>
inline const pb_field_t* GetNanopbFields<firestore_client_WriteBatch>() {
  return firestore_client_WriteBatch_fields;
}

template <>
inline const pb_field_t*
GetNanopbFields<google_firestore_v1_BatchGetDocumentsResponse>() {
  return google_firestore_v1_BatchGetDocumentsResponse_fields;
}

template <>
inline const pb_field_t* GetNanopbFields<google_firestore_v1_ListenResponse>() {
  return google_firestore_v1_ListenResponse_fields;
}

template <>
inline const pb_field_t* GetNanopbFields<google_firestore_v1_WriteResponse>() {
  return google_firestore_v1_WriteResponse_fields;
}

}  // namespace nanopb
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_NANOPB_FIELDS_MAP_H_
