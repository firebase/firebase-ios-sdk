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

#import <OCMock/OCMock.h>

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <FirebaseCore/FirebaseCore.h>
#import "FBLPromise+Testing.h"
#import "FIRInstallationsItem+Tests.h"

#import "FIRInstallations.h"
#import "FIRInstallationsAuthTokenResultInternal.h"
#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsIDController.h"

@interface FIRInstallations (Tests)
@property(nonatomic, readwrite, strong) FIROptions *appOptions;
@property(nonatomic, readwrite, strong) NSString *appName;

- (instancetype)initWithAppOptions:(FIROptions *)appOptions
                           appName:(NSString *)appName
         installationsIDController:(FIRInstallationsIDController *)installationsIDController;

@end

@interface FIRInstallationsTests : XCTestCase
@property(nonatomic) FIRInstallations *installations;
@property(nonatomic) id mockIDController;
@property(nonatomic) FIROptions *appOptions;
@end

@implementation FIRInstallationsTests

- (void)setUp {
  [super setUp];

  self.appOptions = [[FIROptions alloc] initWithGoogleAppID:@"GoogleAppID"
                                                GCMSenderID:@"GCMSenderID"];
  self.mockIDController = OCMClassMock([FIRInstallationsIDController class]);
  self.installations = [[FIRInstallations alloc] initWithAppOptions:self.appOptions
                                                            appName:@"appName"
                                          installationsIDController:self.mockIDController];
}

- (void)tearDown {
  self.installations = nil;
  self.mockIDController = nil;
  [super tearDown];
}

- (void)testInstallationsWithApp {
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp1"];
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp2"];

  [FIRApp resetApps];
}

- (void)testInstallationIDSuccess {
  // Stub get installation.
  FIRInstallationsItem *installation = [FIRInstallationsItem createValidInstallationItem];
  OCMExpect([self.mockIDController getInstallationItem])
      .andReturn([FBLPromise resolvedWith:installation]);

  XCTestExpectation *idExpectation = [self expectationWithDescription:@"InstallationIDSuccess"];
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(identifier);
        XCTAssertEqualObjects(identifier, installation.firebaseInstallationID);

        [idExpectation fulfill];
      }];

  [self waitForExpectations:@[ idExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testInstallationIDError {
  // Stub get installation.
  FBLPromise *errorPromise = [FBLPromise pendingPromise];
  [errorPromise reject:[FIRInstallationsErrorUtil keychainErrorWithFunction:@"test" status:-1]];

  OCMExpect([self.mockIDController getInstallationItem]).andReturn(errorPromise);

  XCTestExpectation *idExpectation = [self expectationWithDescription:@"InstallationIDSuccess"];
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNil(identifier);
        XCTAssertNotNil(error);

        // TODO: the error must be in the public domain.
        XCTAssertEqualObjects(error, errorPromise.error);

        [idExpectation fulfill];
      }];

  [self waitForExpectations:@[ idExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenSuccess {
  FIRInstallationsAuthTokenResult *expectedTokenResult = [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"token" expirationDate:[NSDate dateWithTimeIntervalSinceNow:1000]];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:NO]).andReturn([FBLPromise resolvedWith:expectedTokenResult]);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        XCTAssertNotNil(tokenResult);
        XCTAssertGreaterThan(tokenResult.authToken.length, 0);
        XCTAssertTrue([tokenResult.expirationDate laterDate:[NSDate date]]);
        XCTAssertNil(error);

        [tokenExpectation fulfill];
      }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenError {
  FBLPromise *errorPromise = [FBLPromise pendingPromise];
  [errorPromise reject:[FIRInstallationsErrorUtil APIErrorWithHTTPCode:500]];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:NO]).andReturn(errorPromise);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
   authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                             NSError *_Nullable error) {
     XCTAssertNil(tokenResult);
     XCTAssertEqualObjects(error, errorPromise.error);

     [tokenExpectation fulfill];
   }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenForcingRefreshSuccess {
  FIRInstallationsAuthTokenResult *expectedTokenResult = [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"token" expirationDate:[NSDate dateWithTimeIntervalSinceNow:1000]];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:YES]).andReturn([FBLPromise resolvedWith:expectedTokenResult]);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenForcingRefresh:YES
                   completion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
                     XCTAssertNil(error);
                     XCTAssertNotNil(tokenResult);
                     XCTAssertEqualObjects(tokenResult.authToken, expectedTokenResult.authToken);
                     XCTAssertEqualObjects(tokenResult.expirationDate, expectedTokenResult.expirationDate);
                     [tokenExpectation fulfill];
                   }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testAuthTokenForcingRefreshError {
  FBLPromise *errorPromise = [FBLPromise pendingPromise];
  [errorPromise reject:[FIRInstallationsErrorUtil APIErrorWithHTTPCode:500]];
  OCMExpect([self.mockIDController getAuthTokenForcingRefresh:YES]).andReturn(errorPromise);

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
   authTokenForcingRefresh:YES
   completion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                             NSError *_Nullable error) {
     XCTAssertNil(tokenResult);
     XCTAssertEqualObjects(error, errorPromise.error);

     [tokenExpectation fulfill];
   }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockIDController);
}

- (void)testDeleteSuccess {
  XCTestExpectation *deleteExpectation = [self expectationWithDescription:@"DeleteSuccess"];
  [self.installations deleteWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [deleteExpectation fulfill];
  }];

  [self waitForExpectations:@[ deleteExpectation ] timeout:0.5];
}

#pragma mark - Common

- (FIRInstallations *)assertInstallationsWithAppNamed:(NSString *)appName {
  FIRApp *app = [self createAndConfigureAppWithName:appName];
  FIRInstallations *installations = [FIRInstallations installationsWithApp:app];

  XCTAssertNotNil(installations);
  XCTAssertEqualObjects(installations.appOptions.googleAppID, app.options.googleAppID);
  XCTAssertEqualObjects(installations.appName, app.name);

  return installations;
}

#pragma mark - Helpers

- (FIRApp *)createAndConfigureAppWithName:(NSString *)name {
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:@{
    @"GOOGLE_APP_ID" : @"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa",
  }];
  [FIRApp configureWithName:name options:options];

  return [FIRApp appNamed:name];
}

@end
