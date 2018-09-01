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

#include "Firestore/core/src/firebase/firestore/remote/datastore.h"

#include "Firestore/core/include/firebase/firestore/firestore_errors.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"

namespace firebase {
namespace firestore {
namespace remote {

util::Status Datastore::ConvertStatus(grpc::Status from) {
  if (from.ok()) {
    return {};
  }

  grpc::StatusCode error_code = from.error_code();
  HARD_ASSERT(
      error_code >= grpc::CANCELLED && error_code <= grpc::UNAUTHENTICATED,
      "Unknown gRPC error code: %s", error_code);

  return {static_cast<FirestoreErrorCode>(error_code), from.error_message()};
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
