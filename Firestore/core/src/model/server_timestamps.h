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

#ifndef FIRESTORE_CORE_SRC_MODEL_SERVER_TIMESTAMPS_H_
#define FIRESTORE_CORE_SRC_MODEL_SERVER_TIMESTAMPS_H_

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"

namespace firebase {
namespace firestore {
namespace model {

// Utility methods to handle ServerTimestamps, which are stored using special
// sentinal fields in MapValues.

/**
 * Returns whether the provided value is a field map that contains the
 * sentinel values of a ServerTimestamp.
 */
bool IsServerTimestamp(const google_firestore_v1_Value& value);

/**
 * Returns the local time at which the timestamp was written to the document.
 */
const google_firestore_v1_Value& GetLocalWriteTime(
    const google_firestore_v1_Value& value);

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_SERVER_TIMESTAMPS_H_
