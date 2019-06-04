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

#import "FIRInstallations.h"

@interface FIRInstallations (Tests)
@property(nonatomic, readwrite, strong) NSString *appID;
@property(nonatomic, readwrite, strong) NSString *appName;
@end

@interface FIRInstallationsTests : XCTestCase

@end

@implementation FIRInstallationsTests

- (void)tearDown {
  [FIRApp resetApps];
  [super tearDown];
}

- (void)testInstallationsWithApp {
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp1"];
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp2"];
}

- (void)testInstallationIDSuccess {
  FIRInstallations *installations = [self assertInstallationsWithAppNamed:@"app"];

  XCTestExpectation *idExpectation = [self expectationWithDescription:@"InstallationIDSuccess"];
  [installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNil(error);
        XCTAssertNotNil(identifier);
        XCTAssertGreaterThan(identifier.length, 0);

        [idExpectation fulfill];
      }];

  [self waitForExpectations:@[ idExpectation ] timeout:0.5];
}

- (void)testAuthTokenSuccess {
  FIRInstallations *installations = [self assertInstallationsWithAppNamed:@"app"];

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [installations authTokenWithCompletion:^(FIRAuthTokenResult *_Nullable tokenResult,
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
  FIRInstallations *installations = [self assertInstallationsWithAppNamed:@"app"];

  XCTestExpectation *tokenExpectation = [self expectationWithDescription:@"AuthTokenSuccess"];
  [installations authTokenForcingRefresh:YES
                              completion:^(FIRAuthTokenResult *_Nullable tokenResult,
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
  FIRInstallations *installations = [self assertInstallationsWithAppNamed:@"app"];

  XCTestExpectation *deleteExpectation = [self expectationWithDescription:@"DeleteSuccess"];
  [installations deleteWithCompletion:^(NSError *_Nullable error) {
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
