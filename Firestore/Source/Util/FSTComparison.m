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

#import "FSTComparison.h"

NS_ASSUME_NONNULL_BEGIN

union DoubleBits {
  double d;
  uint64_t bits;
};

const NSComparator FSTNumberComparator = ^NSComparisonResult(NSNumber *left, NSNumber *right) {
  return [left compare:right];
};

const NSComparator FSTStringComparator = ^NSComparisonResult(NSString *left, NSString *right) {
  return FSTCompareStrings(left, right);
};

NSComparisonResult FSTCompareStrings(NSString *left, NSString *right) {
  // NOTE: NSLiteralSearch is necessary to compare the raw character codes. By default,
  // precomposed characters are considered equivalent to their decomposed equivalents.
  return [left compare:right options:NSLiteralSearch];
}

NSComparisonResult FSTCompareBools(BOOL left, BOOL right) {
  if (!left) {
    return right ? NSOrderedAscending : NSOrderedSame;
  } else {
    return right ? NSOrderedSame : NSOrderedDescending;
  }
}

NSComparisonResult FSTCompareInts(int left, int right) {
  if (left > right) {
    return NSOrderedDescending;
  }
  if (right > left) {
    return NSOrderedAscending;
  }
  return NSOrderedSame;
}

NSComparisonResult FSTCompareInt32s(int32_t left, int32_t right) {
  if (left > right) {
    return NSOrderedDescending;
  }
  if (right > left) {
    return NSOrderedAscending;
  }
  return NSOrderedSame;
}

NSComparisonResult FSTCompareInt64s(int64_t left, int64_t right) {
  if (left > right) {
    return NSOrderedDescending;
  }
  if (right > left) {
    return NSOrderedAscending;
  }
  return NSOrderedSame;
}

NSComparisonResult FSTCompareUIntegers(NSUInteger left, NSUInteger right) {
  if (left > right) {
    return NSOrderedDescending;
  }
  if (right > left) {
    return NSOrderedAscending;
  }
  return NSOrderedSame;
}

NSComparisonResult FSTCompareDoubles(double left, double right) {
  // NaN sorts equal to itself and before any other number.
  if (left < right) {
    return NSOrderedAscending;
  } else if (left > right) {
    return NSOrderedDescending;
  } else if (left == right) {
    return NSOrderedSame;
  } else {
    // One or both left and right is NaN.
    if (isnan(left)) {
      return isnan(right) ? NSOrderedSame : NSOrderedAscending;
    } else {
      return NSOrderedDescending;
    }
  }
}

static const double LONG_MIN_VALUE_AS_DOUBLE = (double)LLONG_MIN;
static const double LONG_MAX_VALUE_AS_DOUBLE = (double)LLONG_MAX;

NSComparisonResult FSTCompareMixed(double doubleValue, int64_t longValue) {
  // LLONG_MIN has an exact representation as double, so to check for a value outside the range
  // representable by long, we have to check for strictly less than LLONG_MIN. Note that this also
  // handles negative infinity.
  if (doubleValue < LONG_MIN_VALUE_AS_DOUBLE) {
    return NSOrderedAscending;
  }

  // LLONG_MAX has no exact representation as double (casting as we've done makes 2^63, which is
  // larger than LLONG_MAX), so consider any value greater than or equal to the threshold to be out
  // of range. This also handles positive infinity.
  if (doubleValue >= LONG_MAX_VALUE_AS_DOUBLE) {
    return NSOrderedDescending;
  }

  // In Firestore NaN is defined to compare before all other numbers.
  if (isnan(doubleValue)) {
    return NSOrderedAscending;
  }

  int64_t doubleAsLong = (int64_t)doubleValue;
  NSComparisonResult cmp = FSTCompareInt64s(doubleAsLong, longValue);
  if (cmp != NSOrderedSame) {
    return cmp;
  }

  // At this point the long representations are equal but this could be due to rounding.
  double longAsDouble = (double)longValue;
  return FSTCompareDoubles(doubleValue, longAsDouble);
}

NSComparisonResult FSTCompareBytes(NSData *left, NSData *right) {
  NSUInteger minLength = MIN(left.length, right.length);
  int result = memcmp(left.bytes, right.bytes, minLength);
  if (result < 0) {
    return NSOrderedAscending;
  } else if (result > 0) {
    return NSOrderedDescending;
  } else if (left.length < right.length) {
    return NSOrderedAscending;
  } else if (left.length > right.length) {
    return NSOrderedDescending;
  } else {
    return NSOrderedSame;
  }
}

/** Helper to normalize a double and then return the raw bits as a uint64_t. */
uint64_t FSTDoubleBits(double d) {
  if (isnan(d)) {
    d = NAN;
  }
  union DoubleBits converter = {.d = d};
  return converter.bits;
}

BOOL FSTDoubleBitwiseEquals(double left, double right) {
  return FSTDoubleBits(left) == FSTDoubleBits(right);
}

NSUInteger FSTDoubleBitwiseHash(double d) {
  uint64_t bits = FSTDoubleBits(d);
  // Note that x ^ (x >> 32) works fine for both 32 and 64 bit definitions of NSUInteger
  return (((NSUInteger)bits) ^ (NSUInteger)(bits >> 32));
}

NS_ASSUME_NONNULL_END
