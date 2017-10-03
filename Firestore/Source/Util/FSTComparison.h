/*
 * Copyright 2017 Google
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** Compares two NSStrings. */
NSComparisonResult FSTCompareStrings(NSString *left, NSString *right);

/** Compares two BOOLs. */
NSComparisonResult FSTCompareBools(BOOL left, BOOL right);

/** Compares two integers. */
NSComparisonResult FSTCompareInts(int left, int right);

/** Compares two int32_t. */
NSComparisonResult FSTCompareInt32s(int32_t left, int32_t right);

/** Compares two int64_t. */
NSComparisonResult FSTCompareInt64s(int64_t left, int64_t right);

/** Compares two NSUIntegers. */
NSComparisonResult FSTCompareUIntegers(NSUInteger left, NSUInteger right);

/** Compares two doubles (using Firestore semantics for NaN). */
NSComparisonResult FSTCompareDoubles(double left, double right);

/** Compares a double and an int64_t. */
NSComparisonResult FSTCompareMixed(double doubleValue, int64_t longValue);

/** Compare two NSData byte sequences. */
NSComparisonResult FSTCompareBytes(NSData *left, NSData *right);

/** A simple NSComparator for comparing NSNumber instances. */
extern const NSComparator FSTNumberComparator;

/** A simple NSComparator for comparing NSString instances. */
extern const NSComparator FSTStringComparator;

/**
 * Compares the bitwise representation of two doubles, but normalizes NaN values. This is
 * similar to what the backend and android clients do, including comparing -0.0 as not equal to 0.0.
 */
BOOL FSTDoubleBitwiseEquals(double left, double right);

/**
 * Computes a bitwise hash of a double, but normalizes NaN values, suitable for use when using
 * FSTDoublesAreBitwiseEqual for equality.
 */
NSUInteger FSTDoubleBitwiseHash(double d);

NS_ASSUME_NONNULL_END
