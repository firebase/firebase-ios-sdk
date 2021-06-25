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

#import <OCMock/OCMock.h>

#import "FirebaseDatabase/Sources/Login/FIRDatabaseConnectionContextProvider.h"

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "SharedTestUtilities/AppCheckFake/FIRAppCheckFake.h"
#import "SharedTestUtilities/AppCheckFake/FIRAppCheckTokenResultFake.h"
#import "SharedTestUtilities/FIRAuthInteropFake.h"

@interface FIRDatabaseConnectionContextProviderTests : XCTestCase

@property(nonatomic) FIRAuthInteropFake *authFake;
@property(nonatomic) FIRAppCheckFake *appCheckFake;

@property(strong, nonatomic) FIRAppCheckTokenResultFake *appCheckTokenSuccess;
@property(strong, nonatomic) FIRAppCheckTokenResultFake *appCheckTokenError;

@end

@implementation FIRDatabaseConnectionContextProviderTests

- (void)setUp {
  [super setUp];

  self.appCheckTokenSuccess = [[FIRAppCheckTokenResultFake alloc] initWithToken:@"token" error:nil];
  self.appCheckTokenError = [[FIRAppCheckTokenResultFake alloc]
      initWithToken:@"dummy token"
              error:[NSError errorWithDomain:@"testAppCheckError" code:-1 userInfo:nil]];

  self.appCheckFake = [[FIRAppCheckFake alloc] init];
  self.authFake = [[FIRAuthInteropFake alloc] initWithToken:nil userID:nil error:nil];
}

- (void)tearDown {
  self.appCheckFake = nil;
  self.authFake = nil;

  [super tearDown];
}

- (void)testFetchContextWithAppCheckNoAuthSuccess {
  self.appCheckFake.tokenResult = self.appCheckTokenSuccess;

  __auto_type provider =
      [FIRDatabaseConnectionContextProvider contextProviderWithAuth:nil appCheck:self.appCheckFake];

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  [provider
      fetchContextForcingRefresh:NO
                    withCallback:^(FIRDatabaseConnectionContext *_Nullable context,
                                   NSError *_Nullable error) {
                      XCTAssertNil(error);
                      XCTAssertNil(context.authToken);
                      XCTAssertEqualObjects(context.appCheckToken, self.appCheckTokenSuccess.token);
                      [completionExpectation fulfill];
                    }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
}

- (void)testFetchContextWithAppCheckNoAuthError {
  self.appCheckFake.tokenResult = self.appCheckTokenError;

  __auto_type provider =
      [FIRDatabaseConnectionContextProvider contextProviderWithAuth:nil appCheck:self.appCheckFake];

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  [provider
      fetchContextForcingRefresh:NO
                    withCallback:^(FIRDatabaseConnectionContext *_Nullable context,
                                   NSError *_Nullable error) {
                      XCTAssertNil(error);
                      XCTAssertNil(context.authToken);
                      XCTAssertEqualObjects(context.appCheckToken, self.appCheckTokenError.token);
                      [completionExpectation fulfill];
                    }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
}

- (void)testFetchContextWithAuthNoAppCheckSuccess {
  NSString *expectedAuthToken = @"valid_auth_token";
  self.authFake.token = expectedAuthToken;

  __auto_type provider = [FIRDatabaseConnectionContextProvider contextProviderWithAuth:self.authFake
                                                                              appCheck:nil];

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  [provider fetchContextForcingRefresh:NO
                          withCallback:^(FIRDatabaseConnectionContext *_Nullable context,
                                         NSError *_Nullable error) {
                            XCTAssertNil(error);
                            XCTAssertNil(context.appCheckToken);
                            XCTAssertEqualObjects(context.authToken, expectedAuthToken);
                            [completionExpectation fulfill];
                          }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
}

- (void)testFetchContextWithAuthNoAppCheckError {
  NSError *expectedAuthError = [NSError errorWithDomain:@"testFetchContextWithAuthNoAppCheckError"
                                                   code:-1
                                               userInfo:nil];
  self.authFake.error = expectedAuthError;

  __auto_type provider = [FIRDatabaseConnectionContextProvider contextProviderWithAuth:self.authFake
                                                                              appCheck:nil];

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  [provider fetchContextForcingRefresh:NO
                          withCallback:^(FIRDatabaseConnectionContext *_Nullable context,
                                         NSError *_Nullable error) {
                            XCTAssertNil(context.authToken);
                            XCTAssertNil(context.appCheckToken);
                            XCTAssertEqualObjects(error, expectedAuthError);
                            [completionExpectation fulfill];
                          }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
}

- (void)testFetchContextWithAuthSuccessAppCheckSuccess {
  NSString *expectedAuthToken = @"valid_auth_token";
  self.authFake.token = expectedAuthToken;
  self.appCheckFake.tokenResult = self.appCheckTokenSuccess;

  __auto_type provider =
      [FIRDatabaseConnectionContextProvider contextProviderWithAuth:self.authFake
                                                           appCheck:self.appCheckFake];

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  [provider
      fetchContextForcingRefresh:NO
                    withCallback:^(FIRDatabaseConnectionContext *_Nullable context,
                                   NSError *_Nullable error) {
                      XCTAssertNil(error);
                      XCTAssertEqualObjects(context.appCheckToken, self.appCheckTokenSuccess.token);
                      XCTAssertEqualObjects(context.authToken, expectedAuthToken);
                      [completionExpectation fulfill];
                    }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
}

- (void)testFetchContextWithAuthErrorAppCheckSuccess {
  NSError *expectedAuthError =
      [NSError errorWithDomain:@"testFetchContextWithAuthErrorAppCheckSuccess"
                          code:-1
                      userInfo:nil];
  self.authFake.error = expectedAuthError;
  self.appCheckFake.tokenResult = self.appCheckTokenSuccess;

  __auto_type provider =
      [FIRDatabaseConnectionContextProvider contextProviderWithAuth:self.authFake
                                                           appCheck:self.appCheckFake];

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  [provider
      fetchContextForcingRefresh:NO
                    withCallback:^(FIRDatabaseConnectionContext *_Nullable context,
                                   NSError *_Nullable error) {
                      XCTAssertNil(context.authToken);
                      XCTAssertEqualObjects(error, expectedAuthError);
                      XCTAssertEqualObjects(context.appCheckToken, self.appCheckTokenSuccess.token);
                      [completionExpectation fulfill];
                    }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
}

- (void)testFetchContextWithAuthSuccessAppCheckError {
  NSString *expectedAuthToken = @"valid_auth_token";
  self.authFake.token = expectedAuthToken;
  self.appCheckFake.tokenResult = self.appCheckTokenError;

  __auto_type provider =
      [FIRDatabaseConnectionContextProvider contextProviderWithAuth:self.authFake
                                                           appCheck:self.appCheckFake];

  XCTestExpectation *completionExpectation =
      [self expectationWithDescription:@"completionExpectation"];

  [provider
      fetchContextForcingRefresh:NO
                    withCallback:^(FIRDatabaseConnectionContext *_Nullable context,
                                   NSError *_Nullable error) {
                      XCTAssertNil(error);
                      XCTAssertEqualObjects(context.authToken, expectedAuthToken);
                      XCTAssertEqualObjects(context.appCheckToken, self.appCheckTokenError.token);
                      [completionExpectation fulfill];
                    }];

  [self waitForExpectations:@[ completionExpectation ] timeout:0.5];
}

- (void)testListenForAuthTokenChanges {
  NSString *updatedToken = @"updated_auth_token";
  __auto_type provider =
      [FIRDatabaseConnectionContextProvider contextProviderWithAuth:self.authFake
                                                           appCheck:self.appCheckFake];

  XCTestExpectation *callbackExpectation = [self expectationWithDescription:@"callbackExpectation"];

  [provider listenForAuthTokenChanges:^(NSString *token) {
    XCTAssertEqualObjects(token, updatedToken);
    [callbackExpectation fulfill];
  }];

  // Post auth token change notification.
  [[NSNotificationCenter defaultCenter]
      postNotificationName:FIRAuthStateDidChangeInternalNotification
                    object:self.authFake
                  userInfo:@{FIRAuthStateDidChangeInternalNotificationTokenKey : updatedToken}];

  [self waitForExpectations:@[ callbackExpectation ] timeout:0.5];
}

- (void)testListenForAppCheckTokenChanges {
  NSString *updatedToken = @"updated_app_check_token";
  __auto_type provider =
      [FIRDatabaseConnectionContextProvider contextProviderWithAuth:self.authFake
                                                           appCheck:self.appCheckFake];

  XCTestExpectation *callbackExpectation = [self expectationWithDescription:@"callbackExpectation"];

  [provider listenForAppCheckTokenChanges:^(NSString *token) {
    XCTAssertEqualObjects(token, updatedToken);
    [callbackExpectation fulfill];
  }];

  // Post auth token change notification.
  [[NSNotificationCenter defaultCenter]
      postNotificationName:[self.appCheckFake tokenDidChangeNotificationName]
                    object:self.appCheckFake
                  userInfo:@{
                    [self.appCheckFake notificationTokenKey] : updatedToken,
                    [self.appCheckFake notificationAppNameKey] : @"app_name",
                  }];

  [self waitForExpectations:@[ callbackExpectation ] timeout:0.5];
}

@end
