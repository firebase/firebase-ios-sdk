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

#import <FirebaseAppAttestation/FIRAppAttestationToken.h>
#import "FIRAppAttestStoredToken+FIRAppAttestationToken.h"

#import <GoogleUtilities/GULSecureCoding.h>

@interface FIRAppAttestStoredTokenTests : XCTestCase

@end

@implementation FIRAppAttestStoredTokenTests

- (void)testSecureCoding {
  FIRAppAttestStoredToken *tokenToArchive = [[FIRAppAttestStoredToken alloc] init];
  tokenToArchive.token = @"some_token";
  tokenToArchive.expirationDate = [NSDate date];

  NSError *error;
  NSData *archivedToken = [GULSecureCoding archivedDataWithRootObject:tokenToArchive error:&error];
  XCTAssertNotNil(archivedToken);
  XCTAssertNil(error);

  FIRAppAttestStoredToken *unarchivedToken =
      [GULSecureCoding unarchivedObjectOfClass:[FIRAppAttestStoredToken class]
                                      fromData:archivedToken
                                         error:&error];
  XCTAssertNotNil(unarchivedToken);
  XCTAssertNil(error);
  XCTAssertEqualObjects(unarchivedToken.token, tokenToArchive.token);
  XCTAssertEqualObjects(unarchivedToken.expirationDate, tokenToArchive.expirationDate);
  XCTAssertEqual(unarchivedToken.storageVersion, tokenToArchive.storageVersion);
}

- (void)testConvertingToAndFromFIRAppAttestationToken {
  FIRAppAttestationToken *originalToken =
      [[FIRAppAttestationToken alloc] initWithToken:@"___" expirationDate:[NSDate date]];

  FIRAppAttestStoredToken *storedToken = [[FIRAppAttestStoredToken alloc] init];
  [storedToken updateWithToken:originalToken];
  XCTAssertEqualObjects(originalToken.token, storedToken.token);
  XCTAssertEqualObjects(originalToken.expirationDate, storedToken.expirationDate);

  FIRAppAttestationToken *recoveredToken = [storedToken attestationToken];
  XCTAssertEqualObjects(recoveredToken.token, storedToken.token);
  XCTAssertEqualObjects(recoveredToken.expirationDate, storedToken.expirationDate);
}

@end
