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

#include "Firestore/core/include/firebase/firestore/geo_point.h"

#include "gtest/gtest.h"

namespace firebase {
namespace firestore {

TEST(GeoPoint, Getter) {
  const GeoPoint zero;
  EXPECT_EQ(0, zero.latitude());
  EXPECT_EQ(0, zero.longitude());

  const GeoPoint point{12, 34};
  EXPECT_EQ(12, point.latitude());
  EXPECT_EQ(34, point.longitude());
}

TEST(GeoPoint, Comparison) {
  EXPECT_EQ(GeoPoint(12, 34), GeoPoint(12, 34));
  EXPECT_LT(GeoPoint(12, 34), GeoPoint(34, 12));
  EXPECT_LT(GeoPoint(12, 34), GeoPoint(12, 56));
}

}  // namespace firestore
}  // namespace firebase
