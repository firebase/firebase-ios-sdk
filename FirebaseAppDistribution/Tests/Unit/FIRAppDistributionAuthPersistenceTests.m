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

#import <AppAuth/AppAuth.h>
#import <FirebaseAppDistribution/FIRAppDistributionAuthPersistence+Private.h>
#import <FirebaseAppDistribution/FIRAppDistributionKeychainUtility+Private.h>

@interface FIRAppDistributionAuthPersistenceTests : XCTestCase
@end

@implementation FIRAppDistributionAuthPersistenceTests {
  NSMutableDictionary *_mockKeychainQuery;
  id _mockAuthorizationData;
  id _mockOIDAuthState;
  id _mockKeychainUtility;
  id _partialMockAuthPersitence;
}

- (void)setUp {
  [super setUp];
  _mockKeychainQuery = [NSMutableDictionary
      dictionaryWithObjectsAndKeys:(id) @"thing one", (id) @"another thing", nil];
  _mockKeychainUtility = OCMClassMock([FIRAppDistributionKeychainUtility class]);
  _mockAuthorizationData = [@"this is some password stuff" dataUsingEncoding:NSUTF8StringEncoding];
  _mockOIDAuthState = OCMClassMock([OIDAuthState class]);
  OCMStub(ClassMethod([_mockKeychainUtility unarchiveKeychainResult:[OCMArg any]]))
      .andReturn(_mockOIDAuthState);
  OCMStub(ClassMethod([_mockKeychainUtility archiveDataForKeychain:[OCMArg any]]))
      .andReturn(_mockAuthorizationData);
}

- (void)tearDown {
  [super tearDown];
}

- (void)testPersistAuthStateSuccess {
  OCMStub(ClassMethod([_mockKeychainUtility addKeychainItem:[OCMArg any]
                                         withDataDictionary:[OCMArg any]]))
      .andReturn(YES);
  NSError *error;
  XCTAssertTrue([FIRAppDistributionAuthPersistence persistAuthState:_mockOIDAuthState
                                                              error:&error]);
  XCTAssertNil(error);
}

- (void)testPersistAuthStateFailure {
  OCMStub(ClassMethod([_mockKeychainUtility addKeychainItem:[OCMArg any]
                                         withDataDictionary:[OCMArg any]]))
      .andReturn(NO);
  NSError *error;
  XCTAssertFalse([FIRAppDistributionAuthPersistence persistAuthState:_mockOIDAuthState
                                                               error:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual([error domain], kFIRAppDistributionAuthPersistenceErrorDomain);
  XCTAssertEqual([error code], FIRAppDistributionErrorTokenPersistenceFailure);
}

- (void)testOverwriteAuthStateSuccess {
  OCMStub(ClassMethod([_mockKeychainUtility fetchKeychainItemMatching:[OCMArg any]
                                                                error:[OCMArg setTo:nil]]))
      .andReturn(_mockAuthorizationData);
  OCMStub(ClassMethod([_mockKeychainUtility updateKeychainItem:[OCMArg any]
                                            withDataDictionary:[OCMArg any]]))
      .andReturn(YES);
  NSError *error;
  XCTAssertTrue([FIRAppDistributionAuthPersistence persistAuthState:_mockOIDAuthState
                                                              error:&error]);
  XCTAssertNil(error);
}

- (void)testOverwriteAuthStateFailure {
  OCMStub(ClassMethod([_mockKeychainUtility fetchKeychainItemMatching:[OCMArg any]
                                                                error:[OCMArg setTo:nil]]))
      .andReturn(_mockAuthorizationData);
  OCMStub(ClassMethod([_mockKeychainUtility updateKeychainItem:[OCMArg any]
                                            withDataDictionary:[OCMArg any]]))
      .andReturn(NO);
  NSError *error;
  XCTAssertFalse([FIRAppDistributionAuthPersistence persistAuthState:_mockOIDAuthState
                                                               error:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual([error domain], kFIRAppDistributionAuthPersistenceErrorDomain);
  XCTAssertEqual([error code], FIRAppDistributionErrorTokenPersistenceFailure);
}

- (void)testRetrieveAuthStateSuccess {
  OCMStub(ClassMethod([_mockKeychainUtility fetchKeychainItemMatching:[OCMArg any]
                                                                error:[OCMArg setTo:nil]]))
      .andReturn(_mockAuthorizationData);
  NSError *error;
  XCTAssertTrue([[FIRAppDistributionAuthPersistence retrieveAuthState:&error]
      isKindOfClass:[OIDAuthState class]]);
  XCTAssertNil(error);
}

- (void)testRetrieveAuthStateFailure {
  OCMStub(ClassMethod([_mockKeychainUtility fetchKeychainItemMatching:[OCMArg any]
                                                                error:[OCMArg setTo:nil]]))
      .andReturn(nil);
  NSError *error;
  XCTAssertFalse([FIRAppDistributionAuthPersistence retrieveAuthState:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual([error domain], kFIRAppDistributionAuthPersistenceErrorDomain);
  XCTAssertEqual([error code], FIRAppDistributionErrorTokenRetrievalFailure);
}

- (void)testClearAuthStateSuccess {
  OCMStub(ClassMethod([_mockKeychainUtility deleteKeychainItem:[OCMArg any]])).andReturn(YES);
  NSError *error;
  XCTAssertTrue([FIRAppDistributionAuthPersistence clearAuthState:&error]);
  XCTAssertNil(error);
}

- (void)testClearAuthStateFailure {
  OCMStub(ClassMethod([_mockKeychainUtility deleteKeychainItem:[OCMArg any]])).andReturn(NO);
  NSError *error;
  XCTAssertFalse([FIRAppDistributionAuthPersistence clearAuthState:&error]);
  XCTAssertNotNil(error);
  XCTAssertEqual([error domain], kFIRAppDistributionAuthPersistenceErrorDomain);
  XCTAssertEqual([error code], FIRAppDistributionErrorTokenDeletionFailure);
}

@end
