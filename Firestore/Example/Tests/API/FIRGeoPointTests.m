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

#import "FirebaseFirestore/FIRGeoPoint.h"

#import <XCTest/XCTest.h>

#import "Firestore/Example/Tests/API/FSTAPIHelpers.h"
#import "Firestore/Example/Tests/Util/FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRGeoPointTests : XCTestCase
@end

@implementation FIRGeoPointTests

- (void)testEquals {
  FIRGeoPoint *foo = FSTTestGeoPoint(0, 0);
  FIRGeoPoint *fooDup = FSTTestGeoPoint(0, 0);
  FIRGeoPoint *bar = FSTTestGeoPoint(1.23, 4.56);
  FIRGeoPoint *barDup = FSTTestGeoPoint(1.23, 4.56);
  FIRGeoPoint *differentLatitude = FSTTestGeoPoint(1, 0);
  FIRGeoPoint *differentLongitude = FSTTestGeoPoint(0, 1);
  NSObject *object = [[NSObject alloc] init];
  XCTAssertEqualObjects(foo, fooDup);
  XCTAssertEqualObjects(bar, barDup);
  XCTAssertNotEqualObjects(foo, differentLatitude);
  XCTAssertNotEqualObjects(foo, differentLongitude);
  XCTAssertNotEqualObjects(foo, object);

  XCTAssertEqual([foo hash], [fooDup hash]);
  XCTAssertEqual([bar hash], [barDup hash]);
  XCTAssertNotEqual([foo hash], [differentLatitude hash]);
  XCTAssertNotEqual([foo hash], [differentLongitude hash]);
  XCTAssertNotEqual([foo hash], [object hash]);
}

- (void)testComparison {
  NSArray *values = @[
    @[ [[FIRGeoPoint alloc] initWithLatitude:-90 longitude:-180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:-90 longitude:0] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:-90 longitude:180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:-89 longitude:-180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:-89 longitude:0] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:-89 longitude:180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:0 longitude:-180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:0 longitude:0] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:0 longitude:180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:89 longitude:-180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:89 longitude:0] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:89 longitude:180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:90 longitude:-180] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:90 longitude:0] ],
    @[ [[FIRGeoPoint alloc] initWithLatitude:90 longitude:180] ],
  ];

  FSTAssertComparisons(values);
}

@end

NS_ASSUME_NONNULL_END
