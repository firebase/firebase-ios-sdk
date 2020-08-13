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
#import "OCMock.h"

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FirebaseAuth.h"

#import "FirebaseAuth/Sources/SystemService/FIRAuthStoredUserManager.h"
#import "FirebaseAuth/Tests/Unit/FIRApp+FIRAuthUnitTests.h"

@interface FIRAuth (Test)
@property(nonatomic, strong, nullable) FIRAuthStoredUserManager *storedUserManager;
+ (NSString *)keychainServiceNameForAppName:(NSString *)appName;
@end

@interface UseUserAccessGroupTests : XCTestCase
@end

@implementation UseUserAccessGroupTests

- (void)setUp {
  [super setUp];
  [FIRApp resetAppForAuthUnitTests];
}

- (void)testUseUserAccessGroup {
  id classMock = OCMClassMock([FIRAuth class]);
  OCMStub([classMock keychainServiceNameForAppName:OCMOCK_ANY]).andReturn(nil);
  FIRAuthStoredUserManager *myManager =
      [[FIRAuthStoredUserManager alloc] initWithServiceName:@"MyService"];
  [myManager setStoredUserAccessGroup:@"MyGroup" error:nil];

  FIRAuth *auth = [FIRAuth auth];
  XCTAssertNotNil(auth);
  id partialMock = OCMPartialMock(auth);
  OCMStub([partialMock storedUserManager]).andReturn(myManager);

  XCTAssertNotNil([auth.storedUserManager getStoredUserAccessGroupWithError:nil]);
  XCTAssertTrue([auth useUserAccessGroup:@"id.com.example.group1" error:nil]);
  XCTAssertTrue([auth useUserAccessGroup:@"id.com.example.group2" error:nil]);
  XCTAssertTrue([auth useUserAccessGroup:nil error:nil]);
  [partialMock stopMocking];
}

@end
