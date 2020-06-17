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

#import "FirebaseInstallations/Source/Tests/Utils/FIRKeyedArchivingUtils.h"

#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStoredAuthToken.h"

@interface FIRInstallationsStoredAuthTokenTests : XCTestCase

@end

@implementation FIRInstallationsStoredAuthTokenTests

- (void)testTokenArchivingUnarchiving {
  FIRInstallationsStoredAuthToken *token = [[FIRInstallationsStoredAuthToken alloc] init];
  token.token = @"auth-token";
  token.expirationDate = [NSDate dateWithTimeIntervalSinceNow:12345];
  token.status = FIRInstallationsAuthTokenStatusTokenReceived;

  NSError *error;
  NSData *archivedToken = [FIRKeyedArchivingUtils archivedDataWithRootObject:token error:&error];
  XCTAssertNotNil(archivedToken, @"Error: %@", error);

  FIRInstallationsStoredAuthToken *unarchivedToken =
      [FIRKeyedArchivingUtils unarchivedObjectOfClass:[FIRInstallationsStoredAuthToken class]
                                             fromData:archivedToken
                                                error:&error];
  XCTAssertNotNil(unarchivedToken, @"Error: %@", error);

  XCTAssertEqualObjects(token.token, unarchivedToken.token);
  XCTAssertEqualObjects(token.expirationDate, unarchivedToken.expirationDate);
  XCTAssertEqual(token.status, unarchivedToken.status);
}

@end
