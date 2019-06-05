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
#import <FirebaseCore/FirebaseCore.h>

#import "FIRInstallationsAuthTokenResultInternal.h"
#import "FIRInstallations.h"

@interface FIRInstallations (Tests)
@property(nonatomic, readwrite, strong) NSString *appID;
@property(nonatomic, readwrite, strong) NSString *appName;

- (instancetype)initWithGoogleAppID:(NSString *)appID appName:(NSString *)appName;

@end

@interface FIRInstallationsTests : XCTestCase
@property(nonatomic) FIRInstallations *installations;
@end

@implementation FIRInstallationsTests

- (void)setUp {
  [super setUp];

  self.installations = [[FIRInstallations alloc] initWithGoogleAppID:@"GoogleAppID"
                                                             appName:@"appName"];
}

- (void)tearDown {
  self.installations = nil;
  [super tearDown];
}

- (void)testInstallationsWithApp {
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp1"];
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp2"];

  [FIRApp resetApps];
}

- (void)testInstallationIDSuccess {
  XCTestExpectation *idExpectation = [self expectationWithDescription:@"InstallationIDSuccess"];
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(identifier);
        XCTAssertGreaterThan(identifier.length, 0);

        [idExpectation fulfill];
      }];

  [self waitForExpectations:@[ idExpectation ] timeout:0.5];
}

- (void)testAuthTokenSuccess {
  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenWithCompletion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
        XCTAssertNotNil(tokenResult);
        XCTAssertGreaterThan(tokenResult.authToken.length, 0);
        XCTAssertTrue([tokenResult.expirationTime laterDate:[NSDate date]]);
        XCTAssertNil(error);

        [tokenExpectation fulfill];
      }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];
}

- (void)testAuthTokenForcingRefreshSuccess {
  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [self.installations
      authTokenForcingRefresh:YES
                   completion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
                     XCTAssertNotNil(tokenResult);
                     XCTAssertGreaterThan(tokenResult.authToken.length, 0);
                     XCTAssertTrue([tokenResult.expirationTime laterDate:[NSDate date]]);
                     XCTAssertNil(error);

                     [tokenExpectation fulfill];
                   }];

  [self waitForExpectations:@[ tokenExpectation ] timeout:0.5];
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

  XCTAssertEqualObjects(installations.appID, app.options.googleAppID);
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
