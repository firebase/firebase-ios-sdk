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

#ifndef FIRESTORE_CORE_SRC_MODEL_VALUES_H_
#define FIRESTORE_CORE_SRC_MODEL_VALUES_H_

#include <string>

#include "Firestore/Protos/nanopb/google/firestore/v1/document.nanopb.h"

namespace firebase {
namespace firestore {

namespace util {
enum class ComparisonResult;
}

namespace model {

/**
 * The order of types in Firestore. This order is based on the backend's
 * ordering, but modified to support server timestamps.
 */
enum TypeOrder {
  kTypeOrderNull = 0,
  kTypeOrderBoolean = 1,
  kTypeOrderNumber = 2,
  kTypeOrderTimestamp = 3,
  kTypeOrderServerTimestamp = 4,
  kTypeOrderString = 5,
  kTypeOrderBlob = 6,
  kTypeOrderReference = 7,
  kTypeOrderGeoPoint = 8,
  kTypeOrderArray = 9,
  kTypeOrderMap = 10
};

/** Returns the backend's type order of the given Value type. */
TypeOrder GetTypeOrder(const google_firestore_v1_Value& value);

util::ComparisonResult Compare(const google_firestore_v1_Value& left,
                               const google_firestore_v1_Value& right);

/**
 * Generate the canonical ID for the provided field value (as used in Target
 * serialization).
 */
std::string CanonicalId(const google_firestore_v1_Value& value);

bool operator==(const google_firestore_v1_Value& lhs,
                const google_firestore_v1_Value& rhs);

inline bool operator!=(const google_firestore_v1_Value& lhs,
                       const google_firestore_v1_Value& rhs) {
  return !(lhs == rhs);
}

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_VALUES_H_
