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

#import "Firestore/Source/Model/FSTFieldValue.h"

#import <FirebaseFirestore/FIRGeoPoint.h>
#import <FirebaseFirestore/FIRTimestamp.h>
#import <XCTest/XCTest.h>

#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/API/converters.h"

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

#include "Firestore/core/include/firebase/firestore/geo_point.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/model/field_value.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/testutil.h"
#include "Firestore/core/test/firebase/firestore/testutil/time_testing.h"

namespace testutil = firebase::firestore::testutil;
namespace util = firebase::firestore::util;
using firebase::firestore::GeoPoint;
using firebase::firestore::api::MakeTimestamp;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::FieldValue;

/** Helper to wrap the values in a set of equality groups using FSTTestFieldValue(). */
NSArray *FSTWrapGroups(NSArray *groups) {
  NSMutableArray *wrapped = [NSMutableArray array];
  for (NSArray<id> *group in groups) {
    NSMutableArray *wrappedGroup = [NSMutableArray array];
    for (id value in group) {
      FSTFieldValue *wrappedValue;
      // Server Timestamp values can't be parsed directly, so we have a couple predefined sentinel
      // strings that can be used instead.
      if ([value isEqual:@"server-timestamp-1"]) {
        wrappedValue =
            FieldValue::FromServerTimestamp(testutil::MakeTimestamp(2016, 5, 20, 10, 20, 0)).Wrap();
      } else if ([value isEqual:@"server-timestamp-2"]) {
        wrappedValue =
            FieldValue::FromServerTimestamp(testutil::MakeTimestamp(2016, 10, 21, 15, 32, 0))
                .Wrap();
      } else if ([value isKindOfClass:[FSTDocumentKeyReference class]]) {
        // We directly convert these here so that the databaseIDs can be different.
        FSTDocumentKeyReference *reference = (FSTDocumentKeyReference *)value;
        wrappedValue = FieldValue::FromReference(reference.databaseID, reference.key).Wrap();
      } else {
        wrappedValue = FSTTestFieldValue(value);
      }
      [wrappedGroup addObject:wrappedValue];
    }
    [wrapped addObject:wrappedGroup];
  }
  return wrapped;
}

@interface FSTFieldValueTests : XCTestCase
@end

@implementation FSTFieldValueTests {
  NSDate *date1;
  NSDate *date2;
}

- (void)setUp {
  [super setUp];
  // Create a couple date objects for use in tests.
  date1 = FSTTestDate(2016, 5, 20, 10, 20, 0);
  date2 = FSTTestDate(2016, 10, 21, 15, 32, 0);
}

union DoubleBits {
  double d;
  uint64_t bits;
};

- (void)testNormalizesNaNs {
  // NOTE: With v1 query semantics, it's no longer as important that our NaN representation matches
  // the backend, since all NaNs are defined to sort as equal, but we preserve the normalization and
  // this test regardless for now.

  // We use a canonical NaN bit pattern that's common for both Java and Objective-C. Specifically:
  //   - sign: 0
  //   - exponent: 11 bits, all 1
  //   - significand: 52 bits, MSB=1, rest=0
  //
  // This matches the Firestore backend which uses Java's Double.doubleToLongBits which is defined
  // to normalize all NaNs to this value.
  union DoubleBits canonical = {.bits = 0x7ff8000000000000ULL};

  // IEEE 754 specifies that NaN isn't equal to itself.
  XCTAssertTrue(isnan(canonical.d));
  XCTAssertEqual(canonical.bits, canonical.bits);
  XCTAssertNotEqual(canonical.d, canonical.d);

  // All permutations of the 51 other non-MSB significand bits are also NaNs.
  union DoubleBits alternate = {.bits = 0x7fff000000000000ULL};
  XCTAssertTrue(isnan(alternate.d));
  XCTAssertNotEqual(alternate.bits, canonical.bits);
  XCTAssertNotEqual(alternate.d, canonical.d);

  // Even though at the C-level assignment preserves non-canonical NaNs, NSNumber normalizes all
  // NaNs to single shared instance, kCFNumberNaN. That NaN has no public definition for its value
  // but it happens to match what we need.
  union DoubleBits normalized = {.d = [[NSNumber numberWithDouble:alternate.d] doubleValue]};
  XCTAssertEqual(normalized.bits, canonical.bits);

  // Ensure we get the same normalization behavior (currently implemented explicitly by checking
  // for isnan() and then explicitly assigning NAN).
  union DoubleBits result;
  result.d = FieldValue::FromDouble(canonical.d).double_value();
  XCTAssertEqual(result.bits, canonical.bits);

  result.d = FieldValue::FromDouble(alternate.d).double_value();
  XCTAssertEqual(result.bits, canonical.bits);

  // A NaN that's canonical except it has the sign bit set (would be negative if signs mattered)
  union DoubleBits negative = {.bits = 0xfff8000000000000ULL};
  result.d = FieldValue::FromDouble(negative.d).double_value();
  XCTAssertTrue(isnan(negative.d));
  XCTAssertEqual(result.bits, canonical.bits);

  // A signaling NaN with significand where MSB is 0, and some non-MSB bit is one.
  union DoubleBits signaling = {.bits = 0xfff4000000000000ULL};
  XCTAssertTrue(isnan(signaling.d));
  result.d = FieldValue::FromDouble(signaling.d).double_value();
  XCTAssertEqual(result.bits, canonical.bits);
}

- (void)testZeros {
  // Floating point numbers have an explicit sign bit so it's possible to end up with negative
  // zero as a distinct value from positive zero.
  union DoubleBits zero = {.d = 0.0};
  union DoubleBits negativeZero = {.d = -0.0};

  // IEEE 754 requires these two zeros to compare equal.
  XCTAssertNotEqual(zero.bits, negativeZero.bits);
  XCTAssertEqual(zero.d, negativeZero.d);

  // NSNumber preserves the negative zero value but compares equal according to IEEE 754.
  union DoubleBits normalized = {.d = [[NSNumber numberWithDouble:negativeZero.d] doubleValue]};
  XCTAssertEqual(normalized.bits, negativeZero.bits);
  XCTAssertEqualObjects([NSNumber numberWithDouble:0.0], [NSNumber numberWithDouble:-0.0]);

  // FieldValue::FromDouble preserves positive/negative zero
  union DoubleBits result;
  result.d = FieldValue::FromDouble(zero.d).double_value();
  XCTAssertEqual(result.bits, zero.bits);
  result.d = FieldValue::FromDouble(negativeZero.d).double_value();
  XCTAssertEqual(result.bits, negativeZero.bits);

  // ... but compares positive/negative zero as unequal, compatibly with Firestore.
  XCTAssertNotEqual(FieldValue::FromDouble(0.0), FieldValue::FromDouble(-0.0));
}

- (void)testExtractsFields {
  FSTObjectValue *obj = FSTTestObjectValue(@{@"foo" : @{@"a" : @YES, @"b" : @"string"}});
  FSTAssertIsKindOfClass(obj, FSTObjectValue);

  FSTAssertIsKindOfClass([obj valueForPath:testutil::Field("foo")], FSTObjectValue);
  XCTAssertEqualObjects([obj valueForPath:testutil::Field("foo.a")], FieldValue::True().Wrap());
  XCTAssertEqualObjects([obj valueForPath:testutil::Field("foo.b")],
                        FieldValue::FromString("string").Wrap());

  XCTAssertNil([obj valueForPath:testutil::Field("foo.a.b")]);
  XCTAssertNil([obj valueForPath:testutil::Field("bar")]);
  XCTAssertNil([obj valueForPath:testutil::Field("bar.a")]);
}

- (void)testOverwritesExistingFields {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @"old"});
  FSTObjectValue *mod = [old objectBySettingValue:FSTTestFieldValue(@"mod")
                                          forPath:testutil::Field("a")];

  // Should return a new object, leaving the old one unmodified.
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @"old"}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @"mod"}));
}

- (void)testAddsNewFields {
  FSTObjectValue *empty = [FSTObjectValue objectValue];
  FSTObjectValue *mod = [empty objectBySettingValue:FSTTestFieldValue(@"mod")
                                            forPath:testutil::Field("a")];
  XCTAssertNotEqual(empty, mod);
  XCTAssertEqualObjects(empty, FSTTestFieldValue(@{}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @"mod"}));

  FSTObjectValue *old = mod;
  mod = [old objectBySettingValue:FSTTestFieldValue(@1) forPath:testutil::Field("b")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @"mod"}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @"mod", @"b" : @1}));
}

- (void)testImplicitlyCreatesObjects {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @"old"});
  FSTObjectValue *mod = [old objectBySettingValue:FSTTestFieldValue(@"mod")
                                          forPath:testutil::Field("b.c.d")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @"old"}));
  XCTAssertEqualObjects(mod,
                        FSTTestFieldValue(@{@"a" : @"old", @"b" : @{@"c" : @{@"d" : @"mod"}}}));
}

- (void)testCanOverwritePrimitivesWithObjects {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @{@"b" : @"old"}});
  FSTObjectValue *mod = [old objectBySettingValue:FSTTestFieldValue(@{@"b" : @"mod"})
                                          forPath:testutil::Field("a")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @{@"b" : @"old"}}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @{@"b" : @"mod"}}));
}

- (void)testAddsToNestedObjects {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @{@"b" : @"old"}});
  FSTObjectValue *mod = [old objectBySettingValue:FSTTestFieldValue(@"mod")
                                          forPath:testutil::Field("a.c")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @{@"b" : @"old"}}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @{@"b" : @"old", @"c" : @"mod"}}));
}

- (void)testDeletesKeys {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @1, @"b" : @2});
  FSTObjectValue *mod = [old objectByDeletingPath:testutil::Field("a")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @1, @"b" : @2}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"b" : @2}));

  FSTObjectValue *empty = [mod objectByDeletingPath:testutil::Field("b")];
  XCTAssertNotEqual(mod, empty);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"b" : @2}));
  XCTAssertEqualObjects(empty, FSTTestFieldValue(@{}));
}

- (void)testDeletesHandleMissingKeys {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @{@"b" : @1, @"c" : @2}});
  FSTObjectValue *mod = [old objectByDeletingPath:testutil::Field("b")];
  XCTAssertEqualObjects(old, mod);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @{@"b" : @1, @"c" : @2}}));

  mod = [old objectByDeletingPath:testutil::Field("a.d")];
  XCTAssertEqualObjects(old, mod);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @{@"b" : @1, @"c" : @2}}));

  mod = [old objectByDeletingPath:testutil::Field("a.b.c")];
  XCTAssertEqualObjects(old, mod);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @{@"b" : @1, @"c" : @2}}));
}

- (void)testDeletesNestedKeys {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @{@"b" : @1, @"c" : @{@"d" : @2, @"e" : @3}}});
  FSTObjectValue *mod = [old objectByDeletingPath:testutil::Field("a.c.d")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old,
                        FSTTestFieldValue(@{@"a" : @{@"b" : @1, @"c" : @{@"d" : @2, @"e" : @3}}}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @{@"b" : @1, @"c" : @{@"e" : @3}}}));

  old = mod;
  mod = [old objectByDeletingPath:testutil::Field("a.c")];
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @{@"b" : @1, @"c" : @{@"e" : @3}}}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @{@"b" : @1}}));

  old = mod;
  mod = [old objectByDeletingPath:testutil::Field("a")];
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @{@"b" : @1}}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{}));
}

- (void)testValueEquality {
  DatabaseId database_id("project");
  NSArray *groups = @[
    @[ FSTTestFieldValue(@YES), FieldValue::True().Wrap() ],
    @[ FSTTestFieldValue(@NO), FieldValue::False().Wrap() ],
    @[ FSTTestFieldValue([NSNull null]), FieldValue::Null().Wrap() ],
    @[ FSTTestFieldValue(@(0.0 / 0.0)), FSTTestFieldValue(@(NAN)), FieldValue::Nan().Wrap() ],
    // -0.0 and 0.0 compare: the same (but are not isEqual:)
    @[ FSTTestFieldValue(@(-0.0)) ], @[ FSTTestFieldValue(@0.0) ],
    @[ FSTTestFieldValue(@1), FSTTestFieldValue(@1LL), FieldValue::FromInteger(1LL).Wrap() ],
    // double and unit64_t values can compare: the same (but won't be isEqual:)
    @[ FSTTestFieldValue(@1.0), FieldValue::FromDouble(1.0).Wrap() ],
    @[ FSTTestFieldValue(@1.1), FieldValue::FromDouble(1.1).Wrap() ],
    @[ FSTTestFieldValue(FSTTestData(0, 1, 2, -1)), testutil::BlobValue(0, 1, 2).Wrap() ],
    @[ FSTTestFieldValue(FSTTestData(0, 1, -1)) ],
    @[ FSTTestFieldValue(@"string"), FieldValue::FromString("string").Wrap() ],
    @[ FSTTestFieldValue(@"strin") ],
    @[ FSTTestFieldValue(@"e\u0301b") ],  // latin small letter e + combining acute accent
    @[ FSTTestFieldValue(@"\u00e9a") ],   // latin small letter e with acute accent
    @[ FSTTestFieldValue(date1), FieldValue::FromTimestamp(MakeTimestamp(date1)).Wrap() ],
    @[ FSTTestFieldValue(date2) ],
    @[
      // NOTE: ServerTimestampValues can't be parsed via FSTTestFieldValue().
      FieldValue::FromServerTimestamp(MakeTimestamp(date1)).Wrap(),
      FieldValue::FromServerTimestamp(MakeTimestamp(date1)).Wrap()
    ],
    @[ FieldValue::FromServerTimestamp(MakeTimestamp(date2)).Wrap() ],
    @[ FSTTestFieldValue(FSTTestGeoPoint(0, 1)), FieldValue::FromGeoPoint(GeoPoint(0, 1)).Wrap() ],
    @[ FSTTestFieldValue(FSTTestGeoPoint(1, 0)) ],
    @[
      FieldValue::FromReference(database_id, FSTTestDocKey(@"coll/doc1")).Wrap(),
      FSTTestFieldValue(FSTTestRef("project", DatabaseId::kDefault, @"coll/doc1"))
    ],
    @[ FSTTestRef("project", "(default)", @"coll/doc2") ],
    @[ FSTTestFieldValue(@[ @"foo", @"bar" ]), FSTTestFieldValue(@[ @"foo", @"bar" ]) ],
    @[ FSTTestFieldValue(@[ @"foo", @"bar", @"baz" ]) ], @[ FSTTestFieldValue(@[ @"foo" ]) ],
    @[
      FSTTestFieldValue(@{@"bar" : @1, @"foo" : @2}), FSTTestFieldValue(@{@"foo" : @2, @"bar" : @1})
    ],
    @[ FSTTestFieldValue(@{@"bar" : @2, @"foo" : @1}) ],
    @[ FSTTestFieldValue(@{@"bar" : @1, @"foo" : @1}) ], @[ FSTTestFieldValue(@{@"foo" : @1}) ]
  ];

  FSTAssertEqualityGroups(groups);
}

- (void)testValueOrdering {
  NSArray *groups = @[
    // null first
    @[ [NSNull null] ],

    // booleans
    @[ @NO ], @[ @YES ],

    // numbers
    @[ @(0.0 / 0.0) ], @[ @(-INFINITY) ], @[ @(-DBL_MAX) ], @[ @(LLONG_MIN) ], @[ @(-1.1) ],
    @[ @(-1.0), @(-1LL) ],  // longs and doubles compare the same
    @[ @(-DBL_MIN) ],
    @[ @(-0x1.0p-1074) ],              // negative smallest subnormal
    @[ @(-0.0), @(0.0), @(0LL) ],      // zeros all compare the same
    @[ @(0x1.0p-1074) ],               // positive smallest subnormal
    @[ @(DBL_MIN) ], @[ @1.0, @1LL ],  // longs and doubles compare the same
    @[ @1.1 ], @[ @(LLONG_MAX) ], @[ @(DBL_MAX) ], @[ @(INFINITY) ],

    // timestamps
    @[ date1 ], @[ date2 ],

    // server timestamps come after all concrete timestamps.
    // NOTE: server timestamps can't be parsed directly, so we have special sentinel strings (see
    // FSTWrapGroups()).
    @[ @"server-timestamp-1" ], @[ @"server-timestamp-2" ],

    // strings
    @[ @"" ], @[ @"\000\ud7ff\ue000\uffff" ], @[ @"(╯°□°）╯︵ ┻━┻" ], @[ @"a" ], @[ @"abc def" ],
    @[ @"e\u0301b" ],  // latin small letter e + combining acute accent + latin small letter b
    @[ @"æ" ],
    @[ @"\u00e9a" ],  // latin small letter e with acute accent + latin small letter a

    // blobs
    @[ FSTTestData(-1) ], @[ FSTTestData(0, -1) ], @[ FSTTestData(0, 1, 2, 3, 4, -1) ],
    @[ FSTTestData(0, 1, 2, 4, 3, -1) ], @[ FSTTestData(255, -1) ],

    // resource names
    @[ FSTTestRef("p1", "d1", @"c1/doc1") ], @[ FSTTestRef("p1", "d1", @"c1/doc2") ],
    @[ FSTTestRef("p1", "d1", @"c10/doc1") ], @[ FSTTestRef("p1", "d1", @"c2/doc1") ],
    @[ FSTTestRef("p1", "d2", @"c1/doc1") ], @[ FSTTestRef("p2", "d1", @"c1/doc1") ],

    // Geo points
    @[ FSTTestGeoPoint(-90, -180) ], @[ FSTTestGeoPoint(-90, 0) ], @[ FSTTestGeoPoint(-90, 180) ],
    @[ FSTTestGeoPoint(0, -180) ], @[ FSTTestGeoPoint(0, 0) ], @[ FSTTestGeoPoint(0, 180) ],
    @[ FSTTestGeoPoint(1, -180) ], @[ FSTTestGeoPoint(1, 0) ], @[ FSTTestGeoPoint(1, 180) ],
    @[ FSTTestGeoPoint(90, -180) ], @[ FSTTestGeoPoint(90, 0) ], @[ FSTTestGeoPoint(90, 180) ],

    // Arrays
    @[ @[] ], @[ @[ @"bar" ] ], @[ @[ @"foo" ] ], @[ @[ @"foo", @1 ] ], @[ @[ @"foo", @2 ] ],
    @[ @[ @"foo", @"0" ] ],

    // Objects
    @[ @{@"bar" : @0} ], @[ @{@"bar" : @0, @"foo" : @1} ], @[ @{@"foo" : @1} ], @[ @{@"foo" : @2} ],
    @[ @{@"foo" : @"0"} ]
  ];

  NSArray *wrapped = FSTWrapGroups(groups);
  FSTAssertComparisons(wrapped);
}

@end
