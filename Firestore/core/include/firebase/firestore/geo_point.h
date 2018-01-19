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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_GEO_POINT_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_GEO_POINT_H_

#include <string.h>

namespace firebase {
namespace firestore {

/** Immutable class representing a GeoPoint in Firestore */
class GeoPoint {
 public:
  GeoPoint(double latitude, double longitude);

  double latitude() const {
    return latitude_;
  }

  double longitude() const {
    return longitude_;
  }

 private:
  double latitude_;
  double longitude_;
};

/** Compares against another GeoPoint. */
bool operator<(const GeoPoint& lhs, const GeoPoint& rhs);

inline bool operator>(const GeoPoint& lhs, const GeoPoint& rhs) {
  return rhs < lhs;
}

inline bool operator>=(const GeoPoint& lhs, const GeoPoint& rhs) {
  return !(lhs < rhs);
}

inline bool operator<=(const GeoPoint& lhs, const GeoPoint& rhs) {
  return !(lhs > rhs);
}

inline bool operator!=(const GeoPoint& lhs, const GeoPoint& rhs) {
  return lhs < rhs || lhs > rhs;
}

inline bool operator==(const GeoPoint& lhs, const GeoPoint& rhs) {
  return !(lhs != rhs);
}

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_GEO_POINT_H_
