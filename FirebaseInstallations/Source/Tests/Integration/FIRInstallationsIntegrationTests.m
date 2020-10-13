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

// Uncomment or set the flag in GCC_PREPROCESSOR_DEFINITIONS to enable integration tests.
//#define FIR_INSTALLATIONS_INTEGRATION_TESTS_REQUIRED 1

// macOS requests a user password when accessing the Keychain for the first time,
// so the tests may fail. Disable integration tests on macOS so far.
// TODO: Configure the tests to run on macOS without requesting the keychain password.

#import <TargetConditionals.h>
#if !TARGET_OS_OSX

#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#import "FBLPromise+Testing.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallations+Tests.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsItem+Tests.h"

#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FIRInstallations.h"
#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FIRInstallationsAuthTokenResult.h"

static BOOL sFIRInstallationsFirebaseDefaultAppConfigured = NO;

@interface FIRInstallationsIntegrationTests : XCTestCase
@property(nonatomic) FIRInstallations *installations;
@end

@implementation FIRInstallationsIntegrationTests

- (void)setUp {
  [self configureFirebaseDefaultAppIfCan];

  if (![self isDefaultAppConfigured]) {
    return;
  }

  self.installations = [FIRInstallations installationsWithApp:[FIRApp defaultApp]];
}

- (void)tearDown {
  // Delete the installation.
  [self.installations deleteWithCompletion:^(NSError *_Nullable error){
  }];

  // Wait for any pending background job to be completed.
  FBLWaitForPromisesWithTimeout(10);

  [FIRApp resetApps];
}

- (void)testGetFID {
  if (![self isDefaultAppConfigured]) {
    return;
  }

  NSString *FID1 = [self getFID];
  NSString *FID2 = [self getFID];

  XCTAssertEqualObjects(FID1, FID2);
}

- (void)testAuthToken {
  if (![self isDefaultAppConfigured]) {
    return;
  }

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

- (void)testDeleteInstallation {
  if (![self isDefaultAppConfigured]) {
    return;
  }

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

- (void)testInstallationsWithApp {
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp1"];
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp2"];

  // Wait for finishing all background operations.
  FBLWaitForPromisesWithTimeout(10);
}

- (void)testDefaultAppInstallation {
  if (![self isDefaultAppConfigured]) {
    return;
  }

  XCTAssertNotNil(self.installations);
  XCTAssertEqualObjects(self.installations.appOptions.googleAppID,
                        [FIRApp defaultApp].options.googleAppID);
  XCTAssertEqualObjects(self.installations.appName, [FIRApp defaultApp].name);

  // Wait for finishing all background operations.
  FBLWaitForPromisesWithTimeout(10);
}

#pragma mark - Helpers

- (NSString *)getFID {
  XCTestExpectation *expectation =
      [self expectationWithDescription:[NSString stringWithFormat:@"FID %@", self.name]];

  __block NSString *retrievedID;
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNotNil(identifier);
        XCTAssertNil(error);
        XCTAssertEqual(identifier.length, 22);

        retrievedID = identifier;

        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:2];

  return retrievedID;
}

- (FIRInstallationsAuthTokenResult *)getAuthToken {
  XCTestExpectation *authTokenExpectation =
      [self expectationWithDescription:@"authTokenExpectation"];

  __block FIRInstallationsAuthTokenResult *retrievedTokenResult;
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(tokenResult);
        XCTAssertGreaterThanOrEqual(tokenResult.authToken.length, 10);
        XCTAssertGreaterThanOrEqual([tokenResult.expirationDate timeIntervalSinceNow], 50 * 60);

        retrievedTokenResult = tokenResult;

        [authTokenExpectation fulfill];
      }];

  [self waitForExpectations:@[ authTokenExpectation ] timeout:2];

  return retrievedTokenResult;
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
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa"
                                  GCMSenderID:@"valid_sender_id"];
  options.APIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
  options.projectID = @"project_id";
  [FIRApp configureWithName:name options:options];

  return [FIRApp appNamed:name];
}

- (void)configureFirebaseDefaultAppIfCan {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  NSString *plistPath = [bundle pathForResource:@"GoogleService-Info" ofType:@"plist"];
  if (plistPath == nil) {
    return;
  }

  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:plistPath];
  [FIRApp configureWithOptions:options];
  sFIRInstallationsFirebaseDefaultAppConfigured = YES;
}

- (BOOL)isDefaultAppConfigured {
  if (!sFIRInstallationsFirebaseDefaultAppConfigured) {
#if FIR_INSTALLATIONS_INTEGRATION_TESTS_REQUIRED
    XCTFail(@"GoogleService-Info.plist for integration tests was not found. Please add the file to "
            @"your project.");
#else
    NSLog(@"GoogleService-Info.plist for integration tests was not found. Skipping the test %@",
          self.name);
#endif  // FIR_INSTALLATIONS_INTEGRATION_TESTS_REQUIRED
  }

  return sFIRInstallationsFirebaseDefaultAppConfigured;
}

@end

#endif  // !TARGET_OS_OSX
