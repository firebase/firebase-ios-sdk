// Copyright 2019 Google LLC
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

#import "GoogleUtilities/AppDelegateSwizzler/Internal/GULSceneDelegateSwizzler_Private.h"
#import "GoogleUtilities/AppDelegateSwizzler/Public/GoogleUtilities/GULSceneDelegateSwizzler.h"

#import <XCTest/XCTest.h>
#import <objc/runtime.h>
#import "OCMock.h"

/** Plist key that allows Firebase developers to disable Scene Delegate Proxying.  Source of truth
 * is the GULAppDelegateSwizzler class.
 */
static NSString *const kGULFirebaseSceneDelegateProxyEnabledPlistKey =
    @"FirebaseAppDelegateProxyEnabled";

/** Plist key that allows non-Firebase developers to disable Scene Delegate Proxying.  Source of
 * truth is the GULAppDelegateSwizzler class.
 */
static NSString *const kGULGoogleSceneDelegateProxyEnabledPlistKey =
    @"GoogleUtilitiesAppDelegateProxyEnabled";

#pragma mark - Scene Delegate

#if UISCENE_SUPPORTED

@protocol TestSceneProtocol <UISceneDelegate>
@end

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface GULTestSceneDelegate : NSObject <UISceneDelegate>
@end

@implementation GULTestSceneDelegate
@end

@interface GULSceneDelegateSwizzlerTest : XCTestCase
@end

@implementation GULSceneDelegateSwizzlerTest

- (void)testProxySceneDelegateWithNoSceneDelegate {
  if (@available(iOS 13, tvOS 13, *)) {
    id mockSharedScene = OCMClassMock([UIScene class]);
    OCMStub([mockSharedScene delegate]).andReturn(nil);
    XCTAssertNoThrow([GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:mockSharedScene]);
    [mockSharedScene stopMocking];
    mockSharedScene = nil;
  }
}

- (void)testProxySceneDelegate {
  if (@available(iOS 13, tvOS 13, *)) {
    GULTestSceneDelegate *realSceneDelegate = [[GULTestSceneDelegate alloc] init];
    id mockSharedScene = OCMClassMock([UIScene class]);
    OCMStub([mockSharedScene delegate]).andReturn(realSceneDelegate);
    size_t sizeBefore = class_getInstanceSize([GULTestSceneDelegate class]);

    Class realSceneDelegateClassBefore = [realSceneDelegate class];

    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:mockSharedScene];

    XCTAssertTrue([realSceneDelegate isKindOfClass:[GULTestSceneDelegate class]]);

    NSString *newClassName = NSStringFromClass([realSceneDelegate class]);
    XCTAssertTrue([newClassName hasPrefix:@"GUL_"]);
    // It is no longer GULTestSceneDelegate class instance.
    XCTAssertFalse([realSceneDelegate isMemberOfClass:[GULTestSceneDelegate class]]);

    size_t sizeAfter = class_getInstanceSize([realSceneDelegate class]);

    // Class size must stay the same.
    XCTAssertEqual(sizeBefore, sizeAfter);

    // After being proxied, it should be able to respond to the required method selector.
    XCTAssertTrue([realSceneDelegate respondsToSelector:@selector(scene:openURLContexts:)]);

    // Make sure that the class has changed.
    XCTAssertNotEqualObjects([realSceneDelegate class], realSceneDelegateClassBefore);

    [mockSharedScene stopMocking];
    mockSharedScene = nil;
  }
}

- (void)testProxyProxiedSceneDelegate {
  if (@available(iOS 13, tvOS 13, *)) {
    GULTestSceneDelegate *realSceneDelegate = [[GULTestSceneDelegate alloc] init];
    id mockSharedScene = OCMClassMock([UIScene class]);
    OCMStub([mockSharedScene delegate]).andReturn(realSceneDelegate);

    // Proxy the scene delegate for the 1st time.
    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:mockSharedScene];

    Class realSceneDelegateClassBefore = [realSceneDelegate class];

    // Proxy the scene delegate for the 2nd time.
    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:mockSharedScene];

    // Make sure that the class isn't changed.
    XCTAssertEqualObjects([realSceneDelegate class], realSceneDelegateClassBefore);

    [mockSharedScene stopMocking];
    mockSharedScene = nil;
  }
}

- (void)testSceneOpenURLContextsIsInvokedOnInterceptors {
  if (@available(iOS 13, tvOS 13, *)) {
    NSSet *urlContexts = [NSSet set];

    GULTestSceneDelegate *realSceneDelegate = [[GULTestSceneDelegate alloc] init];
    id mockSharedScene = OCMClassMock([UIScene class]);
    OCMStub([mockSharedScene delegate]).andReturn(realSceneDelegate);

    id interceptor = OCMProtocolMock(@protocol(TestSceneProtocol));
    OCMExpect([interceptor scene:mockSharedScene openURLContexts:urlContexts]);

    id interceptor2 = OCMProtocolMock(@protocol(TestSceneProtocol));
    OCMExpect([interceptor2 scene:mockSharedScene openURLContexts:urlContexts]);

    [GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:mockSharedScene];

    [GULSceneDelegateSwizzler registerSceneDelegateInterceptor:interceptor];
    [GULSceneDelegateSwizzler registerSceneDelegateInterceptor:interceptor2];

    [realSceneDelegate scene:mockSharedScene openURLContexts:urlContexts];
    OCMVerifyAll(interceptor);
    OCMVerifyAll(interceptor2);

    [mockSharedScene stopMocking];
    mockSharedScene = nil;
  }
}

#if !TARGET_OS_MACCATALYST
// Test fails on Catalyst.

- (void)testNotificationCenterRegister {
  if (@available(iOS 13, tvOS 13, *)) {
    [GULSceneDelegateSwizzler proxyOriginalSceneDelegate];

    XCTNSNotificationExpectation *expectation =
        [[XCTNSNotificationExpectation alloc] initWithName:UISceneWillConnectNotification];

    [[NSNotificationCenter defaultCenter]
        postNotification:[NSNotification notificationWithName:UISceneWillConnectNotification
                                                       object:nil]];
    [self waitForExpectations:@[ expectation ] timeout:1];
  }
}
#endif

#pragma mark - Tests to test that Plist flag is honored

/** Tests that scene delegate proxy is enabled when there is no Info.plist dictionary. */
- (void)testAppProxyPlistFlag_NoFlag {
  // No keys anywhere. If there is no key, the default should be enabled.
  NSDictionary *mainDictionary = nil;
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that scene delegate proxy is enabled when there is neither the Firebase nor the
 * non-Firebase Info.plist key present.
 */
- (void)testAppProxyPlistFlag_NoSceneDelegateProxyKey {
  // No scene delegate disable key. If there is no key, the default should be enabled.
  NSDictionary *mainDictionary = @{@"randomKey" : @"randomValue"};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that scene delegate proxy is enabled when the Firebase plist is explicitly set to YES and
 * the Google flag is not present. */
- (void)testAppProxyPlistFlag_FirebaseEnabled {
  // Set proxy enabled to YES.
  NSDictionary *mainDictionary = @{kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(YES)};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that scene delegate proxy is enabled when the Google plist is explicitly set to YES and
 * the Firebase flag is not present. */
- (void)testAppProxyPlistFlag_GoogleEnabled {
  // Set proxy enabled to YES.
  NSDictionary *mainDictionary = @{kGULGoogleSceneDelegateProxyEnabledPlistKey : @(YES)};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that the scene delegate proxy is enabled when the Firebase flag has the wrong type of
 * value and the Google flag is not present. */
- (void)testAppProxyPlist_WrongFirebaseDisableFlagValueType {
  // Set proxy enabled to "NO" - a string.
  NSDictionary *mainDictionary = @{kGULFirebaseSceneDelegateProxyEnabledPlistKey : @"NO"};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that the scene delegate proxy is enabled when the Google flag has the wrong type of value
 * and the Firebase flag is not present. */
- (void)testAppProxyPlist_WrongGoogleDisableFlagValueType {
  // Set proxy enabled to "NO" - a string.
  NSDictionary *mainDictionary = @{kGULGoogleSceneDelegateProxyEnabledPlistKey : @"NO"};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertTrue([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that the scene delegate proxy is disabled when the Firebase flag is set to NO and the
 * Google flag is not present. */
- (void)testAppProxyPlist_FirebaseDisableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(NO)};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is not present. */
- (void)testAppProxyPlist_GoogleDisableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{kGULGoogleSceneDelegateProxyEnabledPlistKey : @(NO)};
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is set to YES. */
- (void)testAppProxyPlist_GoogleDisableFlagFirebaseEnableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{
    kGULGoogleSceneDelegateProxyEnabledPlistKey : @(NO),
    kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(YES)
  };
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is set to YES. */
- (void)testAppProxyPlist_FirebaseDisableFlagGoogleEnableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{
    kGULGoogleSceneDelegateProxyEnabledPlistKey : @(YES),
    kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(NO)
  };
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

/** Tests that the scene delegate proxy is disabled when the Google flag is set to NO and the
 * Firebase flag is set to NO. */
- (void)testAppProxyPlist_FirebaseDisableFlagGoogleDisableFlag {
  // Set proxy enabled to NO.
  NSDictionary *mainDictionary = @{
    kGULGoogleSceneDelegateProxyEnabledPlistKey : @(NO),
    kGULFirebaseSceneDelegateProxyEnabledPlistKey : @(NO)
  };
  id mainBundleMock = OCMPartialMock([NSBundle mainBundle]);
  [[[mainBundleMock expect] andReturn:mainDictionary] infoDictionary];

  XCTAssertFalse([GULSceneDelegateSwizzler isSceneDelegateProxyEnabled]);
  [mainBundleMock stopMocking];
  mainBundleMock = nil;
}

@end

#endif  // UISCENE_SUPPORTED
