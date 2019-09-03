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

#import <XCTest/XCTest.h>

#import <GoogleDataTransport/GDTAssert.h>

@interface GDTAssertBlockedTest : XCTestCase

@end

@implementation GDTAssertBlockedTest

/** Tests that asserting is innocuous and doesn't throw. NS_BLOCK_ASSERTIONS doesn't matter here. */
- (void)testNonFatallyAssertingDoesntThrow {
  GDTAssert(NO, @"test assertion");
}

/** Tests that fatally asserting doesn't throw with NS_BLOCK_ASSERTIONS defined. */
- (void)testFatallyAssertingDoesntThrow {
  GDTFatalAssert(NO, @"test assertion");
}

@end
