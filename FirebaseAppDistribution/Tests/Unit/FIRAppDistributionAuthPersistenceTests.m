//
// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULKeychainUtils.h>

@interface FIRAppDistributionAuthPersistenceTests : XCTestCase
@end

@implementation FIRAppDistributionAuthPersistenceTests {
  NSMutableDictionary *_mockKeychainQuery;
  FIRAppDistributionAuthPersistence *_authPersistence;
  id _mockAuthorizationData;
  id _mockOIDAuthState;
  id _mockKeychainUtility;
  id _mockGoogleKeychainUtilities;
  id _partialMockAuthPersitence;
}

- (void)setUp {
  [super setUp];
  _mockKeychainQuery = [NSMutableDictionary
      dictionaryWithObjectsAndKeys:(id) @"thing one", (id) @"another thing", nil];
  _mockGoogleKeychainUtilities = OCMClassMock([GULKeychainUtils class]);
  _mockAuthorizationData = [@"this is some password stuff" dataUsingEncoding:NSUTF8StringEncoding];
  _mockOIDAuthState = OCMClassMock([OIDAuthState class]);
  _partialMockAuthPersitence = OCMClassMock([FIRAppDistributionAuthPersistence class]);
  _authPersistence = [[FIRAppDistributionAuthPersistence alloc] initWithAppId:@"test-app-id"];
  OCMStub(ClassMethod([_partialMockAuthPersitence unarchiveKeychainResult:[OCMArg any]]))
      .andReturn(_mockOIDAuthState);
  OCMStub(ClassMethod([_partialMockAuthPersitence archiveDataForKeychain:[OCMArg any]]))
      .andReturn(_mockAuthorizationData);
}

- (void)tearDown {
  [super tearDown];
}

- (void)testPersistAuthStateSuccess {
  OCMStub(ClassMethod([_mockGoogleKeychainUtilities setItem:[OCMArg any]
                                                  withQuery:[OCMArg any]
                                                      error:[OCMArg setTo:nil]]))
      .andReturn(YES);
  NSError *error;
  XCTAssertTrue([_authPersistence persistAuthState:_mockOIDAuthState error:&error]);
  XCTAssertNil(error);
}

- (void)testPersistAuthStateFailure {
  OCMStub(ClassMethod([_mockGoogleKeychainUtilities setItem:[OCMArg any]
                                                  withQuery:[OCMArg any]
                                                      error:[OCMArg setTo:nil]]))
      .andReturn(NO);
  NSError *error;
  XCTAssertFalse([_authPersistence persistAuthState:_mockOIDAuthState error:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual([error domain], kFIRAppDistributionAuthPersistenceErrorDomain);
  XCTAssertEqual([error code], FIRAppDistributionErrorTokenPersistenceFailure);
}

- (void)testRetrieveAuthStateSuccess {
  OCMStub(ClassMethod([_mockGoogleKeychainUtilities getItemWithQuery:[OCMArg any]
                                                               error:[OCMArg setTo:nil]]))
      .andReturn(_mockAuthorizationData);
  NSError *error;
  XCTAssertTrue([[_authPersistence retrieveAuthState:&error] isKindOfClass:[OIDAuthState class]]);
  XCTAssertNil(error);
}

- (void)testRetrieveAuthStateFailure {
  OCMStub(ClassMethod([_mockGoogleKeychainUtilities getItemWithQuery:[OCMArg any]
                                                               error:[OCMArg setTo:nil]]))
      .andReturn(nil);
  NSError *error;
  XCTAssertFalse([_authPersistence retrieveAuthState:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual([error domain], kFIRAppDistributionAuthPersistenceErrorDomain);
  XCTAssertEqual([error code], FIRAppDistributionErrorTokenRetrievalFailure);
}

- (void)testClearAuthStateSuccess {
  OCMStub(ClassMethod([_mockGoogleKeychainUtilities removeItemWithQuery:[OCMArg any]
                                                                  error:[OCMArg setTo:nil]]))
      .andReturn(YES);
  NSError *error;
  XCTAssertTrue([_authPersistence clearAuthState:&error]);
  XCTAssertNil(error);
}

- (void)testClearAuthStateFailure {
  OCMStub(ClassMethod([_mockGoogleKeychainUtilities removeItemWithQuery:[OCMArg any]
                                                                  error:[OCMArg setTo:nil]]))
      .andReturn(NO);
  NSError *error;
  XCTAssertFalse([_authPersistence clearAuthState:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual([error domain], kFIRAppDistributionAuthPersistenceErrorDomain);
  XCTAssertEqual([error code], FIRAppDistributionErrorTokenDeletionFailure);
}

@end
