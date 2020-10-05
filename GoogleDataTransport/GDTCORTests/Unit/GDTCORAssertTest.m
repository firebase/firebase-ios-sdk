/*
 * Copyright 2019 Google
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

#undef NS_BLOCK_ASSERTIONS

#import <XCTest/XCTest.h>

#import "GoogleDataTransport/GDTCORLibrary/Internal/GDTCORAssert.h"

@interface GDTCORAssertNotBlockedTest : XCTestCase

@end

@implementation GDTCORAssertNotBlockedTest

/** Tests that asserting is innocuous and doesn't throw. */
- (void)testNonFatallyAssertingDoesntThrow {
  GDTCORAssert(NO, @"test assertion");
}

/** Tests that fatally asserting throws. */
- (void)testFatallyAssertingThrows {
  void (^assertionBlock)(void) = ^{
    GDTCORFatalAssert(NO, @"test assertion")
  };
  void (^assertionBlock2)(void) = ^{
    GDTCORFatalAssert(NO, @"%@", @"test assertion with a format");
  };
  XCTAssertThrows(assertionBlock());
  XCTAssertThrows(assertionBlock2());
}
@end
