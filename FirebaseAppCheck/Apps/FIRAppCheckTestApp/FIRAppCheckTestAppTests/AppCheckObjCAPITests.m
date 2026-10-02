// Copyright 2026 Google LLC
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

#import <XCTest/XCTest.h>

@import FirebaseAppCheck;
@import FirebaseCore;

// The test bundle's own Swift interface, for `AppCheckTestProviderRegistry`.
#import "FIRAppCheckTestAppTests-Swift.h"

/// INT-01 and INT-03: the public API as an Objective-C caller sees it.
///
/// These cases exist because v12 rewrote App Check Core in Swift. Everything a
/// Firebase Objective-C caller touches is now either a Swift type projected
/// back into Objective-C or an Objective-C shim over one, and neither the
/// compiler nor the Swift test suite will notice if that projection regresses.
/// Only Objective-C source can, so this file is deliberately not Swift.
///
/// Scope note: the plan phrased INT-01 against `GACAppCheck` and
/// `GACAppCheckTokenResult`. That is App Check Core's own Objective-C surface,
/// which is covered by the app-check repository's hermetic Objective-C tests.
/// What is untested from there, and tested here, is the `FirebaseAppCheck`
/// layer an app actually links against.

#pragma mark - Objective-C provider

/// A provider written in Objective-C, returning a canned token.
///
/// Implementing `FIRAppCheckProvider` from Objective-C is itself the
/// assertion. The protocol is declared with a completion handler, but the
/// Swift implementations in the SDK satisfy it with `async` functions. If that
/// bridging ever inverts, so that the protocol is only satisfiable from Swift,
/// this file stops compiling, which is exactly when we want to find out.
@interface FIRObjCStubProvider : NSObject <FIRAppCheckProvider>
@property(nonatomic, copy, nullable) NSError *scriptedError;
@property(nonatomic, assign) NSInteger callCount;
@end

@implementation FIRObjCStubProvider

- (void)getTokenWithCompletion:(void (^)(FIRAppCheckToken *_Nullable, NSError *_Nullable))handler {
  self.callCount += 1;
  if (self.scriptedError) {
    handler(nil, self.scriptedError);
    return;
  }
  FIRAppCheckToken *token =
      [[FIRAppCheckToken alloc] initWithToken:@"objc-stub-token"
                               expirationDate:[NSDate dateWithTimeIntervalSinceNow:3600]];
  handler(token, nil);
}

@end

/// An Objective-C factory.
///
/// Unused at runtime now that the shared registry vends providers, but kept
/// deliberately: it has to compile, and that is the assertion. If
/// `FIRAppCheckProviderFactory` ever stops being satisfiable from Objective-C,
/// this file fails to build rather than silently dropping the coverage.
@interface FIRObjCStubProviderFactory : NSObject <FIRAppCheckProviderFactory>
@property(nonatomic, strong) FIRObjCStubProvider *provider;
@end

@implementation FIRObjCStubProviderFactory

- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  return self.provider;
}

@end

#pragma mark - Tests

@interface AppCheckObjCAPITests : XCTestCase
@property(nonatomic, copy) NSString *appName;
@property(nonatomic, strong) FIRObjCStubProvider *provider;
@property(nonatomic, strong) FIRAppCheck *appCheck;
@end

@implementation AppCheckObjCAPITests

- (void)setUp {
  [super setUp];

  // A per-test app name. App Check keys its Keychain cache off the app name,
  // so a shared name would let one test's cached token satisfy another's
  // request and quietly turn a cold-start assertion into a cache read.
  self.appName = [NSString stringWithFormat:@"AppCheckObjC-%@", [[NSUUID UUID] UUIDString]];

  self.provider = [[FIRObjCStubProvider alloc] init];
  // Route through the shared registry rather than installing a factory. XCTest
  // and Swift Testing share a process and are not sequenced against each
  // other, so a global install here would race the Swift suites.
  [[AppCheckTestProviderRegistry shared] register:self.provider forAppNamed:self.appName];

  // Must be hex after the `ios:` segment; FIRApp validates the format.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123456789:ios:abc123"
                                                    GCMSenderID:@"123456789"];
  options.projectID = @"appcheck-harness";
  options.APIKey = @"harness-api-key";
  [FIRApp configureWithName:self.appName options:options];

  FIRApp *app = [FIRApp appNamed:self.appName];
  XCTAssertNotNil(app);
  self.appCheck = [FIRAppCheck appCheckWithApp:app];
  XCTAssertNotNil(self.appCheck);
  self.appCheck.isTokenAutoRefreshEnabled = NO;
}

- (void)tearDown {
  [[AppCheckTestProviderRegistry shared] unregisterAppNamed:self.appName];
  FIRApp *app = [FIRApp appNamed:self.appName];
  if (app) {
    XCTestExpectation *deleted = [self expectationWithDescription:@"app deleted"];
    [app deleteApp:^(BOOL success) {
      [deleted fulfill];
    }];
    [self waitForExpectations:@[ deleted ] timeout:5.0];
  }
  [super tearDown];
}

/// INT-01: the completion-handler API vends usable Objective-C objects.
- (void)testTokenForcingRefreshBridgesToObjectiveC {
  XCTestExpectation *done = [self expectationWithDescription:@"token"];
  __block FIRAppCheckToken *received = nil;
  __block NSError *receivedError = nil;

  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 received = token;
                 receivedError = error;
                 [done fulfill];
               }];

  [self waitForExpectations:@[ done ] timeout:5.0];

  XCTAssertNil(receivedError);
  XCTAssertNotNil(received);
  // Property access through the bridge, not just object identity: a token
  // whose properties come back nil is still a non-nil token.
  XCTAssertEqualObjects(received.token, @"objc-stub-token");
  XCTAssertTrue([received.expirationDate timeIntervalSinceNow] > 0);
  XCTAssertEqual(self.provider.callCount, 1);
}

/// INT-01: the completion handler is delivered on the main queue.
///
/// The Objective-C mirror of INT-05. Worth asserting separately because an
/// Objective-C caller is the one most likely to be updating UIKit directly
/// from this block.
- (void)testCompletionHandlerRunsOnMainThread {
  XCTestExpectation *done = [self expectationWithDescription:@"token"];
  __block BOOL wasMainThread = NO;

  [self.appCheck
      tokenForcingRefresh:NO
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 wasMainThread = [NSThread isMainThread];
                 [done fulfill];
               }];

  [self waitForExpectations:@[ done ] timeout:5.0];
  XCTAssertTrue(wasMainThread, @"v11 delivered completions on the main queue; moving off it "
                               @"is a silent break for callers touching UIKit here.");
}

/// INT-03: the error domain and code an Objective-C caller observes.
///
/// The plan predicted `com.google.app_check_core`. That is the internal core
/// domain; `FIRAppCheckErrorUtil` translates it to `com.firebase.appCheck`
/// before a caller sees it, so asserting the core domain here would have
/// pinned the wrong contract.
- (void)testErrorDomainAndCodeAreTheFirebasePublicDomain {
  self.provider.scriptedError = [NSError errorWithDomain:@"com.google.app_check_core"
                                                    code:4
                                                userInfo:nil];

  XCTestExpectation *done = [self expectationWithDescription:@"error"];
  __block NSError *receivedError = nil;

  [self.appCheck
      tokenForcingRefresh:YES
               completion:^(FIRAppCheckToken *_Nullable token, NSError *_Nullable error) {
                 receivedError = error;
                 [done fulfill];
               }];

  [self waitForExpectations:@[ done ] timeout:5.0];

  XCTAssertNotNil(receivedError);
  XCTAssertEqualObjects(receivedError.domain, FIRAppCheckErrorDomain);
  XCTAssertEqualObjects(FIRAppCheckErrorDomain, @"com.firebase.appCheck");
  // Core code 4 (unsupported) must survive translation as Firebase code 4.
  XCTAssertEqual(receivedError.code, FIRAppCheckErrorCodeUnsupported);
}

/// INT-03: the error enum's raw values are part of the ABI.
///
/// These integers are persisted in callers' analytics and switched on in
/// shipped apps. Renumbering them during the Swift rewrite would be invisible
/// at compile time and silently reclassify every recorded error.
- (void)testErrorCodeRawValuesAreUnchanged {
  XCTAssertEqual(FIRAppCheckErrorCodeUnknown, 0);
  XCTAssertEqual(FIRAppCheckErrorCodeServerUnreachable, 1);
  XCTAssertEqual(FIRAppCheckErrorCodeInvalidConfiguration, 2);
  XCTAssertEqual(FIRAppCheckErrorCodeKeychain, 3);
  XCTAssertEqual(FIRAppCheckErrorCodeUnsupported, 4);
}

@end
