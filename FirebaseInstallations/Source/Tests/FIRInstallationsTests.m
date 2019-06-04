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

#import <FirebaseCore/FirebaseCore.h>
#import "FIRInstallations.h"

#import <FirebaseCore/FIROptionsInternal.h>

@interface FIRInstallations (Tests)
@property (nonatomic, readwrite, strong) NSString *appID;
@property (nonatomic, readwrite, strong) NSString *appName;
@end

@interface FIRInstallationsTests : XCTestCase

@end

@implementation FIRInstallationsTests

- (void)testInstallationsWithApp {
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp1"];
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp2"];
}

#pragma mark - Common

- (void)assertInstallationsWithAppNamed:(NSString *)appName {
  FIRApp *app = [self createAndConfigureAppWithName:appName];

  FIRInstallations *installations = [FIRInstallations installationsWithApp:app];
  XCTAssertEqualObjects(installations.appID, app.options.googleAppID);
  XCTAssertEqualObjects(installations.appName, app.name);
}

#pragma mark - Helpers

- (FIRApp *)createAndConfigureAppWithName:(NSString *)name {
  FIROptions *options = [[FIROptions alloc] initInternalWithOptionsDictionary:@{
          @"GOOGLE_APP_ID" : @"1:1085102361755:ios:f790a919483d5bdf",
        }];
  [FIRApp configureWithName:name options:options];

  return [FIRApp appNamed:name];
}

@end
