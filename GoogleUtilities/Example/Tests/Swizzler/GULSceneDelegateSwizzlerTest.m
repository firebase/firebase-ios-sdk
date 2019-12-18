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

#import <GoogleUtilities/GULSceneDelegateSwizzler.h>
#import "GULSceneDelegateSwizzler_Private.h"

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>
#import <objc/runtime.h>

#if (defined(__IPHONE_9_0) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_9_0))
#define SDK_HAS_USERACTIVITY 1
#endif

/** Plist key that allows Firebase developers to disable App Delegate Proxying.  Source of truth is
 *  the GULAppDelegateSwizzler class.
 */
static NSString *const kGULFirebaseAppDelegateProxyEnabledPlistKey =
    @"FirebaseAppDelegateProxyEnabled";

/** Plist key that allows non-Firebase developers to disable App Delegate Proxying.  Source of truth
 *  is the GULAppDelegateSwizzler class.
 */
static NSString *const kGULGoogleAppDelegateProxyEnabledPlistKey =
    @"GoogleUtilitiesAppDelegateProxyEnabled";

#pragma mark - Scene Delegate

#if ((TARGET_OS_IOS || TARGET_OS_TV) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= 130000))
@protocol TestSceneProtocol <UISceneDelegate>
@end

API_AVAILABLE(ios(13.0), tvos(13.0))
@interface GULTestSceneDelegate : NSObject <UISceneDelegate>
@end

@implementation GULTestSceneDelegate
@end
#endif

@interface GULSceneDelegateSwizzlerTest : XCTestCase
@end

@implementation GULSceneDelegateSwizzlerTest

- (void)setUp {
  [super setUp];
}

- (void)tearDown {
  //  [GULSceneDelegateSwizzler clearInterceptors];
  [super tearDown];
}

#if ((TARGET_OS_IOS || TARGET_OS_TV) && (__IPHONE_OS_VERSION_MAX_ALLOWED >= 130000))

- (void)testProxySceneDelegateWithNoSceneDelegate {
  if (@available(iOS 13, tvOS 13, *)) {
    id mockSharedScene = OCMClassMock([UIScene class]);
    OCMStub([mockSharedScene delegate]).andReturn(nil);
    XCTAssertNoThrow([GULSceneDelegateSwizzler proxySceneDelegateIfNeeded:mockSharedScene]);
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
  }
}

#endif

@end
