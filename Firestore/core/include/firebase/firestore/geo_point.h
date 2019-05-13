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

#include <iosfwd>
#include <string>

namespace firebase {
namespace firestore {

/**
 * An immutable object representing a geographical point in Firestore. The point
 * is represented as a latitude/longitude pair.
 *
 * Latitude values are in the range of [-90, 90].
 * Longitude values are in the range of [-180, 180].
 */
class GeoPoint {
 public:
  /**
   * Creates a `GeoPoint` with both latitude and longitude being 0.
   */
  GeoPoint();

  /**
   * Creates a `GeoPoint` from the provided latitude and longitude degrees.
   *
   * @param latitude The latitude as number between -90 and 90.
   * @param longitude The longitude as number between -180 and 180.
   */
  GeoPoint(double latitude, double longitude);

  GeoPoint(const GeoPoint& other) = default;
  GeoPoint(GeoPoint&& other) = default;
  GeoPoint& operator=(const GeoPoint& other) = default;
  GeoPoint& operator=(GeoPoint&& other) = default;

  double latitude() const {
    return latitude_;
  }

  double longitude() const {
    return longitude_;
  }

  /**
   * Returns a string representation of this `GeoPoint` for logging/debugging
   * purposes.
   *
   * Note: the exact string representation is unspecified and subject to change;
   * don't rely on the format of the string.
   */
  std::string ToString() const;
  friend std::ostream& operator<<(std::ostream& out, const GeoPoint& geo_point);

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
