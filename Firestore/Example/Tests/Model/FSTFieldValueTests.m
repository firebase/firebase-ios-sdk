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

#import <XCTest/XCTest.h>

#import "Firestore/FIRGeoPoint.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FSTUserDataConverter.h"
#import "Firestore/Source/Core/FSTTimestamp.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"

#import "Firestore/Example/Tests/Util/FSTHelpers.h"

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
        wrappedValue = [FSTServerTimestampValue
            serverTimestampValueWithLocalWriteTime:FSTTestTimestamp(2016, 5, 20, 10, 20, 0)];
      } else if ([value isEqual:@"server-timestamp-2"]) {
        wrappedValue = [FSTServerTimestampValue
            serverTimestampValueWithLocalWriteTime:FSTTestTimestamp(2016, 10, 21, 15, 32, 0)];
      } else if ([value isKindOfClass:[FSTDocumentKeyReference class]]) {
        // We directly convert these here so that the databaseIDs can be different.
        FSTDocumentKeyReference *reference = (FSTDocumentKeyReference *)value;
        wrappedValue =
            [FSTReferenceValue referenceValue:reference.key databaseID:reference.databaseID];
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

- (void)testWrapIntegers {
  NSArray *values = @[
    @(INT_MIN), @(-1), @0, @1, @2, @(UCHAR_MAX), @(INT_MAX),  // Standard integers
    @(LONG_MIN), @(LONG_MAX), @(LLONG_MIN), @(LLONG_MAX)      // Larger values
  ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTIntegerValue class]);
    XCTAssertEqualObjects([wrapped value], @([value longLongValue]));
  }
}

- (void)testWrapsDoubles {
  // Note that 0x1.0p-1074 is a hex floating point literal representing the minimum subnormal
  // number: <https://en.wikipedia.org/wiki/Denormal_number>.
  NSArray *values = @[
    @(-INFINITY), @(-DBL_MAX), @(LLONG_MIN * -1.0), @(-1.1), @(-0x1.0p-1074), @(-0.0), @(0.0),
    @(0x1.0p-1074), @(DBL_MIN), @(1.1), @(LLONG_MAX * 1.0), @(DBL_MAX), @(INFINITY)
  ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTDoubleValue class]);
    XCTAssertEqualObjects([wrapped value], value);
  }
}

- (void)testWrapsNilAndNSNull {
  FSTNullValue *nullValue = [FSTNullValue nullValue];
  XCTAssertEqual(FSTTestFieldValue(nil), nullValue);
  XCTAssertEqual(FSTTestFieldValue([NSNull null]), nullValue);
  XCTAssertEqual([nullValue value], [NSNull null]);
}

- (void)testWrapsBooleans {
  NSArray *values = @[ @YES, @NO, [NSNumber numberWithChar:1], [NSNumber numberWithChar:0] ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTBooleanValue class]);
    XCTAssertEqualObjects([wrapped value], value);
  }

  // Unsigned chars could conceivably be handled consistently with signed chars but on arm64 these
  // end up being stored as signed shorts.
  FSTFieldValue *wrapped = FSTTestFieldValue([NSNumber numberWithUnsignedChar:1]);
  XCTAssertEqualObjects(wrapped, [FSTIntegerValue integerValue:1]);
}

union DoubleBits {
  double d;
  uint64_t bits;
};

- (void)testNormalizesNaNs {
  // NOTE: With v1beta1 query semantics, it's no longer as important that our NaN representation
  // matches the backend, since all NaNs are defined to sort as equal, but we preserve the
  // normalization and this test regardless for now.

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
  result.d = [[FSTDoubleValue doubleValue:canonical.d] internalValue];
  XCTAssertEqual(result.bits, canonical.bits);

  result.d = [[FSTDoubleValue doubleValue:alternate.d] internalValue];
  XCTAssertEqual(result.bits, canonical.bits);

  // A NaN that's canonical except it has the sign bit set (would be negative if signs mattered)
  union DoubleBits negative = {.bits = 0xfff8000000000000ULL};
  result.d = [[FSTDoubleValue doubleValue:negative.d] internalValue];
  XCTAssertTrue(isnan(negative.d));
  XCTAssertEqual(result.bits, canonical.bits);

  // A signaling NaN with significand where MSB is 0, and some non-MSB bit is one.
  union DoubleBits signaling = {.bits = 0xfff4000000000000ULL};
  XCTAssertTrue(isnan(signaling.d));
  result.d = [[FSTDoubleValue doubleValue:signaling.d] internalValue];
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

  // FSTDoubleValue preserves positive/negative zero
  union DoubleBits result;
  result.d = [[[FSTDoubleValue doubleValue:zero.d] value] doubleValue];
  XCTAssertEqual(result.bits, zero.bits);
  result.d = [[[FSTDoubleValue doubleValue:negativeZero.d] value] doubleValue];
  XCTAssertEqual(result.bits, negativeZero.bits);

  // ... but compares positive/negative zero as unequal, compatibly with Firestore.
  XCTAssertNotEqualObjects([FSTDoubleValue doubleValue:0.0], [FSTDoubleValue doubleValue:-0.0]);
}

- (void)testWrapStrings {
  NSArray *values = @[ @"", @"abc" ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTStringValue class]);
    XCTAssertEqualObjects([wrapped value], value);
  }
}

- (void)testWrapDates {
  NSArray *values = @[ FSTTestDate(1900, 12, 1, 1, 20, 30), FSTTestDate(2017, 4, 24, 13, 20, 30) ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTTimestampValue class]);
    XCTAssertEqualObjects([wrapped value], value);

    XCTAssertEqualObjects(((FSTTimestampValue *)wrapped).internalValue,
                          [FSTTimestamp timestampWithDate:value]);
  }
}

- (void)testWrapGeoPoints {
  NSArray *values = @[ FSTTestGeoPoint(1.24, 4.56), FSTTestGeoPoint(-20, 100) ];

  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTGeoPointValue class]);
    XCTAssertEqualObjects([wrapped value], value);
  }
}

- (void)testWrapBlobs {
  NSArray *values = @[ FSTTestData(1, 2, 3), FSTTestData(1, 2) ];
  for (id value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTBlobValue class]);
    XCTAssertEqualObjects([wrapped value], value);
  }
}

- (void)testWrapResourceNames {
  NSArray *values = @[
    FSTTestRef(@"project", kDefaultDatabaseID, @"foo/bar"),
    FSTTestRef(@"project", kDefaultDatabaseID, @"foo/baz")
  ];
  for (FSTDocumentKeyReference *value in values) {
    FSTFieldValue *wrapped = FSTTestFieldValue(value);
    XCTAssertEqualObjects([wrapped class], [FSTReferenceValue class]);
    XCTAssertEqualObjects([wrapped value], value.key);
    XCTAssertEqualObjects(((FSTDatabaseID *)wrapped).databaseID, value.databaseID);
  }
}

- (void)testWrapsEmptyObjects {
  XCTAssertEqualObjects(FSTTestFieldValue(@{}), [FSTObjectValue objectValue]);
}

- (void)testWrapsSimpleObjects {
  FSTObjectValue *actual = FSTTestObjectValue(
      @{ @"a" : @"foo",
         @"b" : @(1L),
         @"c" : @YES,
         @"d" : [NSNull null] });
  FSTObjectValue *expected = [[FSTObjectValue alloc] initWithDictionary:@{
    @"a" : [FSTStringValue stringValue:@"foo"],
    @"b" : [FSTIntegerValue integerValue:1LL],
    @"c" : [FSTBooleanValue trueValue],
    @"d" : [FSTNullValue nullValue]
  }];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testWrapsNestedObjects {
  FSTObjectValue *actual = FSTTestObjectValue(@{ @"a" : @{@"b" : @{@"c" : @"foo"}, @"d" : @YES} });
  FSTObjectValue *expected = [[FSTObjectValue alloc] initWithDictionary:@{
    @"a" : [[FSTObjectValue alloc] initWithDictionary:@{
      @"b" :
          [[FSTObjectValue alloc] initWithDictionary:@{@"c" : [FSTStringValue stringValue:@"foo"]}],
      @"d" : [FSTBooleanValue booleanValue:YES]
    }]
  }];
  XCTAssertEqualObjects(actual, expected);
}

- (void)testExtractsFields {
  FSTObjectValue *obj = FSTTestObjectValue(@{ @"foo" : @{@"a" : @YES, @"b" : @"string"} });
  FSTAssertIsKindOfClass(obj, FSTObjectValue);

  FSTAssertIsKindOfClass([obj valueForPath:FSTTestFieldPath(@"foo")], FSTObjectValue);
  XCTAssertEqualObjects([obj valueForPath:FSTTestFieldPath(@"foo.a")], [FSTBooleanValue trueValue]);
  XCTAssertEqualObjects([obj valueForPath:FSTTestFieldPath(@"foo.b")],
                        [FSTStringValue stringValue:@"string"]);

  XCTAssertNil([obj valueForPath:FSTTestFieldPath(@"foo.a.b")]);
  XCTAssertNil([obj valueForPath:FSTTestFieldPath(@"bar")]);
  XCTAssertNil([obj valueForPath:FSTTestFieldPath(@"bar.a")]);
}

- (void)testOverwritesExistingFields {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @"old"});
  FSTObjectValue *mod =
      [old objectBySettingValue:FSTTestFieldValue(@"mod") forPath:FSTTestFieldPath(@"a")];

  // Should return a new object, leaving the old one unmodified.
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @"old"}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @"mod"}));
}

- (void)testAddsNewFields {
  FSTObjectValue *empty = [FSTObjectValue objectValue];
  FSTObjectValue *mod =
      [empty objectBySettingValue:FSTTestFieldValue(@"mod") forPath:FSTTestFieldPath(@"a")];
  XCTAssertNotEqual(empty, mod);
  XCTAssertEqualObjects(empty, FSTTestFieldValue(@{}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{@"a" : @"mod"}));

  FSTObjectValue *old = mod;
  mod = [old objectBySettingValue:FSTTestFieldValue(@1) forPath:FSTTestFieldPath(@"b")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @"mod"}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @"mod", @"b" : @1 }));
}

- (void)testImplicitlyCreatesObjects {
  FSTObjectValue *old = FSTTestObjectValue(@{@"a" : @"old"});
  FSTObjectValue *mod =
      [old objectBySettingValue:FSTTestFieldValue(@"mod") forPath:FSTTestFieldPath(@"b.c.d")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{@"a" : @"old"}));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(
                                 @{ @"a" : @"old",
                                    @"b" : @{@"c" : @{@"d" : @"mod"}} }));
}

- (void)testCanOverwritePrimitivesWithObjects {
  FSTObjectValue *old = FSTTestObjectValue(@{ @"a" : @{@"b" : @"old"} });
  FSTObjectValue *mod =
      [old objectBySettingValue:FSTTestFieldValue(@{@"b" : @"mod"}) forPath:FSTTestFieldPath(@"a")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{ @"a" : @{@"b" : @"old"} }));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @{@"b" : @"mod"} }));
}

- (void)testAddsToNestedObjects {
  FSTObjectValue *old = FSTTestObjectValue(@{ @"a" : @{@"b" : @"old"} });
  FSTObjectValue *mod =
      [old objectBySettingValue:FSTTestFieldValue(@"mod") forPath:FSTTestFieldPath(@"a.c")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{ @"a" : @{@"b" : @"old"} }));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @{@"b" : @"old", @"c" : @"mod"} }));
}

- (void)testDeletesKeys {
  FSTObjectValue *old = FSTTestObjectValue(@{ @"a" : @1, @"b" : @2 });
  FSTObjectValue *mod = [old objectByDeletingPath:FSTTestFieldPath(@"a")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{ @"a" : @1, @"b" : @2 }));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"b" : @2 }));

  FSTObjectValue *empty = [mod objectByDeletingPath:FSTTestFieldPath(@"b")];
  XCTAssertNotEqual(mod, empty);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"b" : @2 }));
  XCTAssertEqualObjects(empty, FSTTestFieldValue(@{}));
}

- (void)testDeletesHandleMissingKeys {
  FSTObjectValue *old = FSTTestObjectValue(@{ @"a" : @{@"b" : @1, @"c" : @2} });
  FSTObjectValue *mod = [old objectByDeletingPath:FSTTestFieldPath(@"b")];
  XCTAssertEqualObjects(old, mod);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @{@"b" : @1, @"c" : @2} }));

  mod = [old objectByDeletingPath:FSTTestFieldPath(@"a.d")];
  XCTAssertEqualObjects(old, mod);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @{@"b" : @1, @"c" : @2} }));

  mod = [old objectByDeletingPath:FSTTestFieldPath(@"a.b.c")];
  XCTAssertEqualObjects(old, mod);
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @{@"b" : @1, @"c" : @2} }));
}

- (void)testDeletesNestedKeys {
  FSTObjectValue *old = FSTTestObjectValue(
      @{ @"a" : @{@"b" : @1, @"c" : @{@"d" : @2, @"e" : @3}} });
  FSTObjectValue *mod = [old objectByDeletingPath:FSTTestFieldPath(@"a.c.d")];
  XCTAssertNotEqual(old, mod);
  XCTAssertEqualObjects(old, FSTTestFieldValue(
                                 @{ @"a" : @{@"b" : @1, @"c" : @{@"d" : @2, @"e" : @3}} }));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @{@"b" : @1, @"c" : @{@"e" : @3}} }));

  old = mod;
  mod = [old objectByDeletingPath:FSTTestFieldPath(@"a.c")];
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{ @"a" : @{@"b" : @1, @"c" : @{@"e" : @3}} }));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{ @"a" : @{@"b" : @1} }));

  old = mod;
  mod = [old objectByDeletingPath:FSTTestFieldPath(@"a")];
  XCTAssertEqualObjects(old, FSTTestFieldValue(@{ @"a" : @{@"b" : @1} }));
  XCTAssertEqualObjects(mod, FSTTestFieldValue(@{}));
}

- (void)testArrays {
  FSTArrayValue *expected = [[FSTArrayValue alloc]
      initWithValueNoCopy:@[ [FSTStringValue stringValue:@"value"], [FSTBooleanValue trueValue] ]];

  FSTArrayValue *actual = (FSTArrayValue *)FSTTestFieldValue(@[ @"value", @YES ]);
  XCTAssertEqualObjects(actual, expected);
}

- (void)testValueEquality {
  NSArray *groups = @[
    @[ FSTTestFieldValue(@YES), [FSTBooleanValue booleanValue:YES] ],
    @[ FSTTestFieldValue(@NO), [FSTBooleanValue booleanValue:NO] ],
    @[ FSTTestFieldValue([NSNull null]), [FSTNullValue nullValue] ],
    @[ FSTTestFieldValue(@(0.0 / 0.0)), FSTTestFieldValue(@(NAN)), [FSTDoubleValue nanValue] ],
    // -0.0 and 0.0 compare: the same (but are not isEqual:)
    @[ FSTTestFieldValue(@(-0.0)) ], @[ FSTTestFieldValue(@0.0) ],
    @[ FSTTestFieldValue(@1), FSTTestFieldValue(@1LL), [FSTIntegerValue integerValue:1LL] ],
    // double and unit64_t values can compare: the same (but won't be isEqual:)
    @[ FSTTestFieldValue(@1.0), [FSTDoubleValue doubleValue:1.0] ],
    @[ FSTTestFieldValue(@1.1), [FSTDoubleValue doubleValue:1.1] ],
    @[
      FSTTestFieldValue(FSTTestData(0, 1, 2, -1)), [FSTBlobValue blobValue:FSTTestData(0, 1, 2, -1)]
    ],
    @[ FSTTestFieldValue(FSTTestData(0, 1, -1)) ],
    @[ FSTTestFieldValue(@"string"), [FSTStringValue stringValue:@"string"] ],
    @[ FSTTestFieldValue(@"strin") ],
    @[ FSTTestFieldValue(@"e\u0301b") ],  // latin small letter e + combining acute accent
    @[ FSTTestFieldValue(@"\u00e9a") ],   // latin small letter e with acute accent
    @[
      FSTTestFieldValue(date1),
      [FSTTimestampValue timestampValue:[FSTTimestamp timestampWithDate:date1]]
    ],
    @[ FSTTestFieldValue(date2) ],
    @[
      // NOTE: ServerTimestampValues can't be parsed via FSTTestFieldValue().
      [FSTServerTimestampValue
          serverTimestampValueWithLocalWriteTime:[FSTTimestamp timestampWithDate:date1]],
      [FSTServerTimestampValue
          serverTimestampValueWithLocalWriteTime:[FSTTimestamp timestampWithDate:date1]]
    ],
    @[ [FSTServerTimestampValue
        serverTimestampValueWithLocalWriteTime:[FSTTimestamp timestampWithDate:date2]] ],
    @[
      FSTTestFieldValue(FSTTestGeoPoint(0, 1)),
      [FSTGeoPointValue geoPointValue:FSTTestGeoPoint(0, 1)]
    ],
    @[ FSTTestFieldValue(FSTTestGeoPoint(1, 0)) ],
    @[
      [FSTReferenceValue referenceValue:FSTTestDocKey(@"coll/doc1")
                             databaseID:[FSTDatabaseID databaseIDWithProject:@"project"
                                                                    database:kDefaultDatabaseID]],
      FSTTestFieldValue(FSTTestRef(@"project", kDefaultDatabaseID, @"coll/doc1"))
    ],
    @[ FSTTestRef(@"project", @"(default)", @"coll/doc2") ],
    @[ FSTTestFieldValue(@[ @"foo", @"bar" ]), FSTTestFieldValue(@[ @"foo", @"bar" ]) ],
    @[ FSTTestFieldValue(@[ @"foo", @"bar", @"baz" ]) ], @[ FSTTestFieldValue(@[ @"foo" ]) ],
    @[
      FSTTestFieldValue(
          @{ @"bar" : @1,
             @"foo" : @2 }),
      FSTTestFieldValue(
          @{ @"foo" : @2,
             @"bar" : @1 })
    ],
    @[ FSTTestFieldValue(
        @{ @"bar" : @2,
           @"foo" : @1 }) ],
    @[ FSTTestFieldValue(
        @{ @"bar" : @1,
           @"foo" : @1 }) ],
    @[ FSTTestFieldValue(
        @{ @"foo" : @1 }) ]
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
    @[ FSTTestRef(@"p1", @"d1", @"c1/doc1") ], @[ FSTTestRef(@"p1", @"d1", @"c1/doc2") ],
    @[ FSTTestRef(@"p1", @"d1", @"c10/doc1") ], @[ FSTTestRef(@"p1", @"d1", @"c2/doc1") ],
    @[ FSTTestRef(@"p1", @"d2", @"c1/doc1") ], @[ FSTTestRef(@"p2", @"d1", @"c1/doc1") ],

    // Geo points
    @[ FSTTestGeoPoint(-90, -180) ], @[ FSTTestGeoPoint(-90, 0) ], @[ FSTTestGeoPoint(-90, 180) ],
    @[ FSTTestGeoPoint(0, -180) ], @[ FSTTestGeoPoint(0, 0) ], @[ FSTTestGeoPoint(0, 180) ],
    @[ FSTTestGeoPoint(1, -180) ], @[ FSTTestGeoPoint(1, 0) ], @[ FSTTestGeoPoint(1, 180) ],
    @[ FSTTestGeoPoint(90, -180) ], @[ FSTTestGeoPoint(90, 0) ], @[ FSTTestGeoPoint(90, 180) ],

    // Arrays
    @[ @[] ], @[ @[ @"bar" ] ], @[ @[ @"foo" ] ], @[ @[ @"foo", @1 ] ], @[ @[ @"foo", @2 ] ],
    @[ @[ @"foo", @"0" ] ],

    // Objects
    @[
      @{ @"bar" : @0 }
    ],
    @[
      @{ @"bar" : @0,
         @"foo" : @1 }
    ],
    @[
      @{ @"foo" : @1 }
    ],
    @[
      @{ @"foo" : @2 }
    ],
    @[ @{@"foo" : @"0"} ]
  ];

  NSArray *wrapped = FSTWrapGroups(groups);
  FSTAssertComparisons(wrapped);
}

- (void)testValue {
  NSDate *date = [NSDate date];
  id input = @{ @"array" : @[ @1, date ], @"obj" : @{@"date" : date, @"string" : @"hi"} };
  FSTObjectValue *value = FSTTestObjectValue(input);
  id output = [value value];
  {
    XCTAssertTrue([output[@"array"][1] isKindOfClass:[NSDate class]]);
    NSDate *actual = output[@"array"][1];
    XCTAssertEqualWithAccuracy(date.timeIntervalSince1970, actual.timeIntervalSince1970,
                               0.000000001);
  }
  {
    XCTAssertTrue([output[@"obj"][@"date"] isKindOfClass:[NSDate class]]);
    NSDate *actual = output[@"obj"][@"date"];
    XCTAssertEqualWithAccuracy(date.timeIntervalSince1970, actual.timeIntervalSince1970,
                               0.000000001);
  }
}

@end
