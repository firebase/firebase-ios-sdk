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
const int32_t kTypeOrderNull = 0;
const int32_t kTypeOrderBoolean = 1;
const int32_t kTypeOrderNumber = 2;
const int32_t kTypeOrderTimestamp = 3;
const int32_t kTypeOrderServerTimestamp = 4;
const int32_t kTypeOrderString = 5;
const int32_t kTypeOrderBlob = 6;
const int32_t kTypeOrderReference = 7;
const int32_t kTypeOrderGeoPoint = 8;
const int32_t kTypeOrderArray = 9;
const int32_t kTypeOrderMap = 10;

class Values {
 public:
  /** Returns the backend's type order of the given Value type. */
  static int32_t GetTypeOrder(const google_firestore_v1_Value& value);

  static bool Equals(const google_firestore_v1_Value& left,
                     const google_firestore_v1_Value& right);

  static util::ComparisonResult Compare(const google_firestore_v1_Value& left,
                                        const google_firestore_v1_Value& right);

  /** Generate the canonical ID for the provided field value (as used in Target
   * serialization). */
  static std::string CanonicalId(const google_firestore_v1_Value& value);

 private:
  Values() = default;

  static bool NumberEquals(const google_firestore_v1_Value& left,
                           const google_firestore_v1_Value& right);

  static bool ArrayEquals(const google_firestore_v1_Value& left,
                          const google_firestore_v1_Value& right);

  static bool ObjectEquals(const google_firestore_v1_Value& left,
                           const google_firestore_v1_Value& right);

  static util::ComparisonResult CompareNumbers(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);
  static util::ComparisonResult CompareTimestamps(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);
  static util::ComparisonResult CompareStrings(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);
  static util::ComparisonResult CompareBlobs(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);
  static util::ComparisonResult CompareReferences(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);
  static util::ComparisonResult CompareGeoPoints(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);
  static util::ComparisonResult CompareArrays(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);
  static util::ComparisonResult CompareObjects(
      const google_firestore_v1_Value& left,
      const google_firestore_v1_Value& right);

  static std::string CanonifyTimestamp(const google_firestore_v1_Value& value);
  static std::string CanonifyBlob(const google_firestore_v1_Value& value);
  static std::string CanonifyReference(const google_firestore_v1_Value& value);
  static std::string CanonifyGeoPoint(const google_firestore_v1_Value& value);
  static std::string CanonifyArray(const google_firestore_v1_Value& value);
  static std::string CanonifyObject(const google_firestore_v1_Value& value);
};

}  // namespace model
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_MODEL_VALUES_H_
