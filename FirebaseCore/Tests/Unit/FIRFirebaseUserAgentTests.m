// Copyright 2022 Google LLC
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

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <XCTest/XCTest.h>

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"
#import "FirebaseCore/Tests/Unit/FIRTestComponents.h"

#import "FirebaseCore/Extension/FIRAppInternal.h"

@interface FIRFirebaseUserAgentTests : FIRTestCase

@end

@implementation FIRFirebaseUserAgentTests

- (void)testFirebaseUserAgent_ApplePlatformFlag {
  // When a Catalyst app is run on macOS then both `TARGET_OS_MACCATALYST` and `TARGET_OS_IOS` are
  // `true`.
#if TARGET_OS_MACCATALYST
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#elif TARGET_OS_IOS
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_MACCATALYST

#if TARGET_OS_TV
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_TV

#if TARGET_OS_OSX
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_OSX

#if TARGET_OS_WATCH
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/ios"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/tvos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/macos"]);
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"apple-platform/watchos"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"apple-platform/maccatalyst"]);
#endif  // TARGET_OS_WATCH
}

- (void)testFirebaseUserAgent_DeploymentType {
#if SWIFT_PACKAGE
  NSString *deploymentType = @"swiftpm";
#elif FIREBASE_BUILD_CARTHAGE
  NSString *deploymentType = @"carthage";
#elif FIREBASE_BUILD_ZIP_FILE
  NSString *deploymentType = @"zip";
#else
  NSString *deploymentType = @"cocoapods";
#endif

  NSString *expectedComponent = [NSString stringWithFormat:@"deploy/%@", deploymentType];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

- (void)testFirebaseUserAgent_DeviceModel {
  NSString *expectedComponent =
      [NSString stringWithFormat:@"device/%@", [GULAppEnvironmentUtil deviceModel]];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

- (void)testFirebaseUserAgent_OSVersion {
  NSString *expectedComponent =
      [NSString stringWithFormat:@"os-version/%@", [GULAppEnvironmentUtil systemVersion]];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

- (void)testFirebaseUserAgent_IsFromAppStore {
  NSString *appStoreValue = [GULAppEnvironmentUtil isFromAppStore] ? @"true" : @"false";
  NSString *expectedComponent = [NSString stringWithFormat:@"appstore/%@", appStoreValue];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:expectedComponent]);
}

- (void)testRegisterLibrary_InvalidLibraryName {
  NSString *originalFirebaseUserAgent = [FIRApp firebaseUserAgent];
  [FIRApp registerLibrary:@"Oops>" withVersion:@"1.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] isEqualToString:originalFirebaseUserAgent]);
}

- (void)testRegisterLibrary_InvalidLibraryVersion {
  NSString *originalFirebaseUserAgent = [FIRApp firebaseUserAgent];
  [FIRApp registerLibrary:@"ValidName" withVersion:@"1.0.0+"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] isEqualToString:originalFirebaseUserAgent]);
}

- (void)testRegisterLibrary_SingleLibrary {
  [FIRApp registerLibrary:@"ValidName" withVersion:@"1.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"ValidName/1.0.0"]);
}

- (void)testRegisterLibrary_MultipleLibraries {
  [FIRApp registerLibrary:@"ValidName" withVersion:@"1.0.0"];
  [FIRApp registerLibrary:@"ValidName2" withVersion:@"2.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"ValidName/1.0.0 ValidName2/2.0.0"]);
}

- (void)testRegisterLibrary_RegisteringConformingLibrary {
  Class testClass = [FIRTestClass class];
  [FIRApp registerInternalLibrary:testClass withName:@"ValidName" withVersion:@"1.0.0"];
  XCTAssertTrue([[FIRApp firebaseUserAgent] containsString:@"ValidName/1.0.0"]);
}

- (void)testRegisterLibrary_RegisteringNonConformingLibrary {
  XCTAssertThrows([FIRApp registerInternalLibrary:[NSString class]
                                         withName:@"InvalidLibrary"
                                      withVersion:@"1.0.0"]);
  XCTAssertFalse([[FIRApp firebaseUserAgent] containsString:@"InvalidLibrary`/1.0.0"]);
}

@end
