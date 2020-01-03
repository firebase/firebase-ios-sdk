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

@end

#endif  // UISCENE_SUPPORTED
