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

#import "Firestore/FIRGeoPoint.h"

#import <XCTest/XCTest.h>

#import "FSTHelpers.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRGeoPointTests : XCTestCase
@end

@implementation FIRGeoPointTests

- (void)testEquals {
  XCTAssertEqualObjects([[FIRGeoPoint alloc] initWithLatitude:0 longitude:0],
                        [[FIRGeoPoint alloc] initWithLatitude:0 longitude:0]);
  XCTAssertEqualObjects([[FIRGeoPoint alloc] initWithLatitude:1.23 longitude:4.56],
                        [[FIRGeoPoint alloc] initWithLatitude:1.23 longitude:4.56]);
  XCTAssertNotEqualObjects([[FIRGeoPoint alloc] initWithLatitude:0 longitude:0],
                           [[FIRGeoPoint alloc] initWithLatitude:1 longitude:0]);
  XCTAssertNotEqualObjects([[FIRGeoPoint alloc] initWithLatitude:0 longitude:0],
                           [[FIRGeoPoint alloc] initWithLatitude:0 longitude:1]);
  XCTAssertNotEqualObjects([[FIRGeoPoint alloc] initWithLatitude:0 longitude:0],
                           [[NSObject alloc] init]);
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
