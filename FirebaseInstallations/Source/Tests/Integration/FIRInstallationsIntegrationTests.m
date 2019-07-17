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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>

#import "FBLPromise+Testing.h"
#import "FIRInstallationsItem+Tests.h"
#import "FIRInstallations+Tests.h"

#import <FirebaseInstallations/FIRInstallations.h>
#import <FirebaseInstallations/FIRInstallationsAuthTokenResult.h>

@interface FIRInstallationsIntegrationTests : XCTestCase
@property(nonatomic) FIRInstallations *installations;
@end

@implementation FIRInstallationsIntegrationTests

- (void)setUp {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [FIRApp configure];
  });

  self.installations = [FIRInstallations installationsWithApp:[FIRApp defaultApp]];
}

- (void)tearDown {
  // Delete the installation.
  [self.installations deleteWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
  }];

  // Wait for any pending background job to be completed.
  FBLWaitForPromisesWithTimeout(10);
}

// TODO: Enable the test once Travis configured.
// Need to configure the GoogleService-Info.plist copying from the encrypted archive.
// So far, let's run the tests locally.
- (void)disabled_testGetFID {
  NSString *FID1 = [self getFID];
  NSString *FID2 = [self getFID];

  XCTAssertEqualObjects(FID1, FID2);
}

- (void)disabled_testAuthToken {
  XCTestExpectation *authTokenExpectation =
      [self expectationWithDescription:@"authTokenExpectation"];

  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(tokenResult);
        XCTAssertGreaterThanOrEqual(tokenResult.authToken.length, 10);
        XCTAssertGreaterThanOrEqual([tokenResult.expirationDate timeIntervalSinceNow], 50 * 60);

        [authTokenExpectation fulfill];
      }];

  [self waitForExpectations:@[ authTokenExpectation ] timeout:2];
}

- (void)disabled_testDeleteInstallation {
  NSString *FIDBefore = [self getFID];
  FIRInstallationsAuthTokenResult *authTokenBefore = [self getAuthToken];

  XCTestExpectation *deleteExpectation = [self expectationWithDescription:@"Delete Installation"];
  [self.installations deleteWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [deleteExpectation fulfill];
  }];
  [self waitForExpectations:@[ deleteExpectation ] timeout:2];

  NSString *FIDAfter = [self getFID];
  FIRInstallationsAuthTokenResult *authTokenAfter = [self getAuthToken];

  XCTAssertNotEqualObjects(FIDBefore, FIDAfter);
  XCTAssertNotEqualObjects(authTokenBefore.authToken, authTokenAfter.authToken);
  XCTAssertNotEqualObjects(authTokenBefore.expirationDate, authTokenAfter.expirationDate);
}

// TODO: Configure the tests to run on macOS without requesting the keychain password.
#if !TARGET_OS_OSX
- (void)testInstallationsWithApp {
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp1"];
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp2"];

  // Wait for finishing all background operations.
  FBLWaitForPromisesWithTimeout(10);

  [FIRApp resetApps];
}

- (void)testDefaultAppInstallation {
  XCTAssertNotNil(self.installations);
  XCTAssertEqualObjects(self.installations.appOptions.googleAppID, [FIRApp defaultApp].options.googleAppID);
  XCTAssertEqualObjects(self.installations.appName, [FIRApp defaultApp].name);

  // Wait for finishing all background operations.
  FBLWaitForPromisesWithTimeout(10);

  [FIRApp resetApps];
}

#endif // !TARGET_OS_OSX

#pragma mark - Helpers

- (NSString *)getFID {
  XCTestExpectation *expectation =
      [self expectationWithDescription:[NSString stringWithFormat:@"FID %@", self.name]];

  __block NSString *retreivedID;
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNotNil(identifier);
        XCTAssertNil(error);
        XCTAssertEqual(identifier.length, 22);

        retreivedID = identifier;

        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:2];

  return retreivedID;
}

- (FIRInstallationsAuthTokenResult *)getAuthToken {
  XCTestExpectation *authTokenExpectation =
      [self expectationWithDescription:@"authTokenExpectation"];

  __block FIRInstallationsAuthTokenResult *retreivedTokenResult;
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(tokenResult);
        XCTAssertGreaterThanOrEqual(tokenResult.authToken.length, 10);
        XCTAssertGreaterThanOrEqual([tokenResult.expirationDate timeIntervalSinceNow], 50 * 60);

        retreivedTokenResult = tokenResult;

        [authTokenExpectation fulfill];
      }];

  [self waitForExpectations:@[ authTokenExpectation ] timeout:2];

  return retreivedTokenResult;
}

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
    @"GCM_SENDER_ID" : @"valid_sender_id"
  }];
  [FIRApp configureWithName:name options:options];

  return [FIRApp appNamed:name];
}

@end
