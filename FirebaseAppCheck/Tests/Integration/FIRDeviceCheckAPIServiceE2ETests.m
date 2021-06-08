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

#import "FBLPromise+Testing.h"

#import <FirebaseCore/FirebaseCore.h>

#import "FirebaseAppCheck/Sources/Core/APIService/FIRAppCheckAPIService.h"
#import "FirebaseAppCheck/Sources/DeviceCheckProvider/API/FIRDeviceCheckAPIService.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckToken.h"

@interface FIRDeviceCheckAPIServiceE2ETests : XCTestCase
@property(nonatomic) FIRDeviceCheckAPIService *deviceCheckAPIService;
@property(nonatomic) FIRAppCheckAPIService *APIService;
@property(nonatomic) NSURLSession *URLSession;
@end

@implementation FIRDeviceCheckAPIServiceE2ETests

- (void)setUp {
  self.URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  FIROptions *options = [self firebaseTestOptions];
  self.APIService = [[FIRAppCheckAPIService alloc] initWithURLSession:self.URLSession
                                                               APIKey:options.APIKey
                                                            projectID:options.projectID
                                                                appID:options.googleAppID];
  self.deviceCheckAPIService =
      [[FIRDeviceCheckAPIService alloc] initWithAPIService:self.APIService
                                                 projectID:options.projectID
                                                     appID:options.googleAppID];
}

- (void)tearDown {
  self.deviceCheckAPIService = nil;
  self.APIService = nil;
  self.URLSession = nil;
}

// TODO: Re-enable the test once secret with "GoogleService-Info.plist" is configured.
- (void)temporaryDisabled_testAppCheckTokenSuccess {
  __auto_type appCheckPromise =
      [self.deviceCheckAPIService appCheckTokenWithDeviceToken:[NSData data]];

  XCTAssert(FBLWaitForPromisesWithTimeout(20));

  XCTAssertNil(appCheckPromise.error);
  XCTAssertNotNil(appCheckPromise.value);

  XCTAssertNotNil(appCheckPromise.value.token);
  XCTAssertNotNil(appCheckPromise.value.expirationDate);
}

#pragma mark - Helpers

- (FIROptions *)firebaseTestOptions {
  NSString *plistPath =
      [[NSBundle bundleForClass:[self class]] pathForResource:@"GoogleService-Info"
                                                       ofType:@"plist"];
  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:plistPath];
  return options;
}

@end
