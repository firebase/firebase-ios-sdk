/*
 * Copyright 2025 Google LLC
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

#include "Firestore/core/test/unit/testutil/expression_test_util.h"

#include <limits>  // For std::numeric_limits
#include <memory>  // For std::shared_ptr
#include <vector>

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/model/value_util.h"  // For Value, Array, Map, BlobValue, RefValue

namespace firebase {
namespace firestore {
namespace testutil {

// Assuming Java long maps to int64_t in C++
const int64_t kMaxLongExactlyRepresentableAsDouble = 1LL
                                                     << 53;  // 9007199254740992

// --- Initialize Static Data Members ---

const std::vector<std::shared_ptr<Expr>>
    ComparisonValueTestData::BOOLEAN_VALUES = {SharedConstant(false),
                                               SharedConstant(true)};

const std::vector<std::shared_ptr<Expr>>
    ComparisonValueTestData::NUMERIC_VALUES = {
        SharedConstant(-std::numeric_limits<double>::infinity()),
        SharedConstant(-std::numeric_limits<double>::max()),
        SharedConstant(std::numeric_limits<int64_t>::min()),
        SharedConstant(-kMaxLongExactlyRepresentableAsDouble),
        SharedConstant(-1LL),
        SharedConstant(-0.5),
        SharedConstant(-std::numeric_limits<double>::min()),  // -MIN_NORMAL
        SharedConstant(
            -std::numeric_limits<double>::denorm_min()),  // -MIN_VALUE
                                                          // (denormalized)
        SharedConstant(
            0.0),  // Include 0.0 (represents both 0.0 and -0.0 for ordering)
        SharedConstant(
            std::numeric_limits<double>::denorm_min()),      // MIN_VALUE
                                                             // (denormalized)
        SharedConstant(std::numeric_limits<double>::min()),  // MIN_NORMAL
        SharedConstant(0.5),
        SharedConstant(1LL),
        SharedConstant(42LL),
        SharedConstant(kMaxLongExactlyRepresentableAsDouble),
        SharedConstant(std::numeric_limits<int64_t>::max()),
        SharedConstant(std::numeric_limits<double>::max()),
        SharedConstant(std::numeric_limits<double>::infinity()),
};

const std::vector<std::shared_ptr<Expr>>
    ComparisonValueTestData::TIMESTAMP_VALUES = {
        SharedConstant(Timestamp(-42, 0)),
        SharedConstant(Timestamp(-42, 42000000)),  // 42 ms = 42,000,000 ns
        SharedConstant(Timestamp(0, 0)),
        SharedConstant(Timestamp(0, 42000000)),
        SharedConstant(Timestamp(42, 0)),
        SharedConstant(Timestamp(42, 42000000))};

const std::vector<std::shared_ptr<Expr>>
    ComparisonValueTestData::STRING_VALUES = {
        SharedConstant(""), SharedConstant("abcdefgh"),
        // SharedConstant("fouxdufafa".repeat(200)), // String repeat not std
        // C++
        SharedConstant("santé"), SharedConstant("santé et bonheur")};

const auto ComparisonValueTestData::BYTE_VALUES =
    std::vector<std::shared_ptr<Expr>>{
        SharedConstant(*BlobValue()),  // Empty - use default constructor
        SharedConstant(*BlobValue(0, 2, 56, 42)),  // Use variadic args
        SharedConstant(*BlobValue(2, 26)),         // Use variadic args
        SharedConstant(*BlobValue(2, 26, 31)),     // Use variadic args
        // SharedConstant(*BlobValue(std::vector<uint8_t>(...))), // Large blob
    };

const std::vector<std::shared_ptr<Expr>>
    ComparisonValueTestData::ENTITY_REF_VALUES = {
        RefConstant("foo/bar"),          RefConstant("foo/bar/qux/a"),
        RefConstant("foo/bar/qux/bleh"), RefConstant("foo/bar/qux/hi"),
        RefConstant("foo/bar/tonk/a"),   RefConstant("foo/baz")};

const std::vector<std::shared_ptr<Expr>> ComparisonValueTestData::GEO_VALUES = {
    SharedConstant(GeoPoint(-87.0, -92.0)),
    SharedConstant(GeoPoint(-87.0, 0.0)),
    SharedConstant(GeoPoint(-87.0, 42.0)),
    SharedConstant(GeoPoint(0.0, -92.0)),
    SharedConstant(GeoPoint(0.0, 0.0)),
    SharedConstant(GeoPoint(0.0, 42.0)),
    SharedConstant(GeoPoint(42.0, -92.0)),
    SharedConstant(GeoPoint(42.0, 0.0)),
    SharedConstant(GeoPoint(42.0, 42.0))};

const std::vector<std::shared_ptr<Expr>> ComparisonValueTestData::ARRAY_VALUES =
    {SharedConstant(Array()),
     SharedConstant(Array(true, 15LL)),
     SharedConstant(Array(1LL, 2LL)),
     SharedConstant(Array(Value(Timestamp(12, 0)))),
     SharedConstant(Array("foo")),
     SharedConstant(Array("foo", "bar")),
     SharedConstant(Array(Value(GeoPoint(0, 0)))),
     SharedConstant(Array(Map()))};

const std::vector<std::shared_ptr<Expr>> ComparisonValueTestData::MAP_VALUES = {
    SharedConstant(Map()),
    SharedConstant(Map("ABA", "qux")),
    SharedConstant(Map("aba", "hello")),
    SharedConstant(Map("aba", "hello", "foo", true)),
    SharedConstant(Map("aba", "qux")),
    SharedConstant(Map("foo", "aaa"))};

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
