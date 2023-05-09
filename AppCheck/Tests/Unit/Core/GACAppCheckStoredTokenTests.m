/*
 * Copyright 2020 Google LLC
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

#import "AppCheck/Sources/Core/GACAppCheckToken+Internal.h"
#import "AppCheck/Sources/Core/Storage/GACAppCheckStoredToken+GACAppCheckToken.h"
#import "AppCheck/Sources/Core/Storage/GACAppCheckStoredToken.h"

#import <GoogleUtilities/GULSecureCoding.h>

@interface GACAppCheckStoredTokenTests : XCTestCase

@end

@implementation GACAppCheckStoredTokenTests

- (void)testSecureCoding {
  GACAppCheckStoredToken *tokenToArchive = [[GACAppCheckStoredToken alloc] init];
  tokenToArchive.token = @"some_token";
  tokenToArchive.expirationDate = [NSDate date];
  tokenToArchive.receivedAtDate = [tokenToArchive.expirationDate dateByAddingTimeInterval:-10];

  NSError *error;
  NSData *archivedToken = [GULSecureCoding archivedDataWithRootObject:tokenToArchive error:&error];
  XCTAssertNotNil(archivedToken);
  XCTAssertNil(error);

  GACAppCheckStoredToken *unarchivedToken =
      [GULSecureCoding unarchivedObjectOfClass:[GACAppCheckStoredToken class]
                                      fromData:archivedToken
                                         error:&error];
  XCTAssertNotNil(unarchivedToken);
  XCTAssertNil(error);
  XCTAssertEqualObjects(unarchivedToken.token, tokenToArchive.token);
  XCTAssertEqualObjects(unarchivedToken.expirationDate, tokenToArchive.expirationDate);
  XCTAssertEqualObjects(unarchivedToken.receivedAtDate, tokenToArchive.receivedAtDate);
  XCTAssertEqual(unarchivedToken.storageVersion, tokenToArchive.storageVersion);
}

- (void)testConvertingToAndFromGACAppCheckToken {
  GACAppCheckToken *originalToken = [[GACAppCheckToken alloc] initWithToken:@"___"
                                                             expirationDate:[NSDate date]
                                                             receivedAtDate:[NSDate date]];

  GACAppCheckStoredToken *storedToken = [[GACAppCheckStoredToken alloc] init];
  [storedToken updateWithToken:originalToken];
  XCTAssertEqualObjects(originalToken.token, storedToken.token);
  XCTAssertEqualObjects(originalToken.expirationDate, storedToken.expirationDate);
  XCTAssertEqualObjects(originalToken.receivedAtDate, storedToken.receivedAtDate);

  GACAppCheckToken *recoveredToken = [storedToken appCheckToken];
  XCTAssertEqualObjects(recoveredToken.token, storedToken.token);
  XCTAssertEqualObjects(recoveredToken.expirationDate, storedToken.expirationDate);
  XCTAssertEqualObjects(recoveredToken.receivedAtDate, storedToken.receivedAtDate);
}

@end
