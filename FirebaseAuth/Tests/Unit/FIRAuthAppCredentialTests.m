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

#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/SystemService/FIRAuthAppCredential.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kReceipt
    @brief The fake receipt value for testing.
 */
static NSString *const kReceipt = @"RECEIPT";

/** @var kSecret
    @brief The fake secret value for testing.
 */
static NSString *const kSecret = @"SECRET";

/** @class FIRAuthAppCredentialTests
    @brief Unit tests for @c FIRAuthAppCredential .
 */
@interface FIRAuthAppCredentialTests : XCTestCase
@end
@implementation FIRAuthAppCredentialTests

/** @fn testInitializer
    @brief Tests the initializer of the class.
 */
- (void)testInitializer {
  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kReceipt
                                                                            secret:kSecret];
  XCTAssertEqualObjects(credential.receipt, kReceipt);
  XCTAssertEqualObjects(credential.secret, kSecret);
}

/** @fn testSecureCoding
    @brief Tests the implementation of NSSecureCoding protocol.
 */
- (void)testSecureCoding {
  XCTAssertTrue([FIRAuthAppCredential supportsSecureCoding]);

  FIRAuthAppCredential *credential = [[FIRAuthAppCredential alloc] initWithReceipt:kReceipt
                                                                            secret:kSecret];
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:credential];
  XCTAssertNotNil(data);
  FIRAuthAppCredential *otherCredential = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  XCTAssertEqualObjects(otherCredential.receipt, kReceipt);
  XCTAssertEqualObjects(otherCredential.secret, kSecret);
}

@end

NS_ASSUME_NONNULL_END
