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

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/SystemService/FIRAuthAPNSToken.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRAuthAPNSTokenTests
    @brief Unit tests for @c FIRAuthAPNSToken .
 */
@interface FIRAuthAPNSTokenTests : XCTestCase
@end
@implementation FIRAuthAPNSTokenTests

/** @fn testProperties
    @brief Tests the properties of the class.
 */
- (void)testProperties {
  NSData *data = [@"asdf" dataUsingEncoding:NSUTF8StringEncoding];
  FIRAuthAPNSToken *token = [[FIRAuthAPNSToken alloc] initWithData:data
                                                              type:FIRAuthAPNSTokenTypeProd];
  XCTAssertEqualObjects(token.data, data);
  XCTAssertEqualObjects(token.string, @"61736466");  // hex string representation of "asdf"
  XCTAssertEqual(token.type, FIRAuthAPNSTokenTypeProd);
}

@end

NS_ASSUME_NONNULL_END

#endif
