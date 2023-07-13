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

#import <TargetConditionals.h>

// Tests that use the Keychain require a host app and Swift Package Manager
// does not support adding a host app to test targets.
#if !SWIFT_PACKAGE

// Skip keychain tests on Catalyst and macOS. Tests are skipped because they
// involve interactions with the keychain that require a provisioning profile.
// See go/firebase-macos-keychain-popups for more details.
#if !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#import <XCTest/XCTest.h>

#import "FBLPromise+Testing.h"

#import <FirebaseCore/FirebaseCore.h>
#import <FirebaseCoreExtension/FirebaseCoreInternal.h>

#import "AppCheck/Sources/Core/APIService/GACAppCheckAPIService.h"
#import "AppCheck/Sources/DeviceCheckProvider/API/GACDeviceCheckAPIService.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckToken.h"

// TODO(andrewheard): Remove from generic App Check SDK.
// FIREBASE_APP_CHECK_ONLY_BEGIN
static NSString *const kHeartbeatKey = @"X-firebase-client";
// FIREBASE_APP_CHECK_ONLY_END

@interface GACDeviceCheckAPIServiceE2ETests : XCTestCase
@property(nonatomic) GACDeviceCheckAPIService *deviceCheckAPIService;
@property(nonatomic) GACAppCheckAPIService *APIService;
@property(nonatomic) NSURLSession *URLSession;
@end

// TODO(ncooke3): Fix these tests up and get them running on CI.

@implementation GACDeviceCheckAPIServiceE2ETests

- (void)setUp {
  self.URLSession = [NSURLSession
      sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
  FIROptions *options = [self firebaseTestOptions];
  FIRHeartbeatLogger *heartbeatLogger =
      [[FIRHeartbeatLogger alloc] initWithAppID:options.googleAppID];
  GACAppCheckAPIRequestHook heartbeatLoggerHook = ^(NSMutableURLRequest *request) {
    [request setValue:FIRHeaderValueFromHeartbeatsPayload(
                          [heartbeatLogger flushHeartbeatsIntoPayload])
        forHTTPHeaderField:kHeartbeatKey];
  };

  self.APIService = [[GACAppCheckAPIService alloc] initWithURLSession:self.URLSession
                                                               APIKey:options.APIKey
                                                         requestHooks:@[ heartbeatLoggerHook ]];
  self.deviceCheckAPIService = [[GACDeviceCheckAPIService alloc]
      initWithAPIService:self.APIService
            resourceName:[GACDeviceCheckAPIServiceE2ETests resourceNameFromOptions:options]];
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

// TODO(andrewheard): Remove from generic App Check SDK.
// FIREBASE_APP_CHECK_ONLY_BEGIN

+ (NSString *)resourceNameFromOptions:(FIROptions *)options {
  return [NSString stringWithFormat:@"projects/%@/apps/%@", options.projectID, options.googleAppID];
}

// FIREBASE_APP_CHECK_ONLY_END

@end

#endif  // !TARGET_OS_MACCATALYST && !TARGET_OS_OSX

#endif  // !SWIFT_PACKAGE
