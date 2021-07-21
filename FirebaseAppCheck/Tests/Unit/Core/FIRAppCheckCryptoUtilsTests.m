/*
 * Copyright 2021 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/Utils/FIRAppCheckCryptoUtils.h"

@interface FIRAppCheckCryptoUtilsTests : XCTestCase

@end

@implementation FIRAppCheckCryptoUtilsTests

- (void)testSHA256HashFromData {
  NSData *dataToHash = [@"some data to hash" dataUsingEncoding:NSUTF8StringEncoding];

  NSData *hashData = [FIRAppCheckCryptoUtils sha256HashFromData:dataToHash];

  // Convert to a base64 encoded string to compare.
  NSString *base64EncodedHashString = [hashData base64EncodedStringWithOptions:0];

  // Base64 encoded hash of UTF8 encoded string "some data to hash".
  NSString *expectedHashString = @"ai2iCUOTHpg0/BLP5btHu9muQ0iaMHJpYrV29OOZPlA=";

  XCTAssertEqualObjects(base64EncodedHashString, expectedHashString);
}

@end
