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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_COMPARISON_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_COMPARISON_H_

#if __OBJC__
#import <Foundation/Foundation.h>
#endif

#include <sys/types.h>

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/strings/string_view.h"

namespace firebase {
namespace firestore {
namespace util {

/**
 * An enumeration describing the result of a three-way comparison among
 * strongly-ordered values (i.e. where comparison between values always yields
 * less-than, equal-to, or greater-than).
 *
 * This is equivalent to:
 *
 *   * NSComparisonResult from the iOS/macOS Foundation framework.
 *   * std::strong_ordering from C++20
 *
 * The values of the constants are specifically chosen so as to make casting
 * between this type and NSComparisonResult possible.
 */
enum class ComparisonResult {
  /** The left hand side was less than the right. */
  Ascending = -1,

  /** The left hand side was equal to the right. */
  Same = 0,

  /** The left hand side was greater than the right. */
  Descending = 1
};

/**
 * Returns the reverse order (i.e. Ascending => Descending) etc.
 */
constexpr ComparisonResult ReverseOrder(ComparisonResult result) {
  return static_cast<ComparisonResult>(-static_cast<int>(result));
}

/**
 * A generalized comparator for types in Firestore, with ordering defined
 * according to Firestore's semantics. This is useful as argument to e.g.
 * std::sort.
 *
 * Comparators are only defined for the limited set of types for which
 * Firestore defines an ordering.
 */
template <typename T>
struct Comparator {
  // By default comparison is not defined
};

/** Compares two strings. */
template <>
struct Comparator<absl::string_view> {
  bool operator()(const absl::string_view& left,
                  const absl::string_view& right) const;
};

template <>
struct Comparator<std::string> {
  bool operator()(const std::string& left, const std::string& right) const;
};

/** Compares two bools: false < true. */
template <>
struct Comparator<bool> : public std::less<bool> {};

/** Compares two int32_t. */
template <>
struct Comparator<int32_t> : public std::less<int32_t> {};

/** Compares two int64_t. */
template <>
struct Comparator<int64_t> : public std::less<int64_t> {};

/** Compares two doubles (using Firestore semantics for NaN). */
template <>
struct Comparator<double> {
  bool operator()(double left, double right) const;
};

/** Compare two byte sequences. */
// TODO(wilhuff): perhaps absl::Span<uint8_t> would be better?
template <>
struct Comparator<std::vector<uint8_t>>
    : public std::less<std::vector<uint8_t>> {};

/**
 * Perform a three-way comparison between the left and right values using
 * the appropriate Comparator for the values based on their type.
 */
template <typename T, typename C = Comparator<T>>
ComparisonResult Compare(const T& left,
                         const T& right,
                         const C& less_than = C()) {
  if (less_than(left, right)) {
    return ComparisonResult::Ascending;
  } else if (less_than(right, left)) {
    return ComparisonResult::Descending;
  } else {
    return ComparisonResult::Same;
  }
}

#if __OBJC__
/**
 * Returns true if the given ComparisonResult and NSComparisonResult have the
 * same integer values (at compile time).
 */
constexpr bool EqualValue(ComparisonResult lhs, NSComparisonResult rhs) {
  return static_cast<int>(lhs) == static_cast<int>(rhs);
}

/**
 * Performs a three-way comparison, identically to Compare, but converts the
 * result to an NSComparisonResult.
 *
 * This function exists for interoperation with Objective-C++ and should
 * eventually be removed.
 */
template <typename T>
inline NSComparisonResult WrapCompare(const T& left, const T& right) {
  static_assert(EqualValue(ComparisonResult::Ascending, NSOrderedAscending),
                "Ascending invalid");
  static_assert(EqualValue(ComparisonResult::Same, NSOrderedSame),
                "Same invalid");
  static_assert(EqualValue(ComparisonResult::Descending, NSOrderedDescending),
                "Descending invalid");

  return static_cast<NSComparisonResult>(Compare<T>(left, right));
}
#endif

/** Compares a double and an int64_t. */
ComparisonResult CompareMixedNumber(double doubleValue, int64_t longValue);

/** Normalizes a double and then return the raw bits as a uint64_t. */
uint64_t DoubleBits(double d);

/**
 * Compares the bitwise representation of two doubles, but normalizes NaN
 * values. This is similar to what the backend and android clients do, including
 * comparing -0.0 as not equal to 0.0.
 */
bool DoubleBitwiseEquals(double left, double right);

/**
 * Computes a bitwise hash of a double, but normalizes NaN values, suitable for
 * use when using FSTDoublesAreBitwiseEqual for equality.
 */
size_t DoubleBitwiseHash(double d);

}  // namespace util
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_UTIL_COMPARISON_H_
