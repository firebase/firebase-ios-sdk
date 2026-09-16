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

#import <TargetConditionals.h>
#if TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION

#import "FirebaseCore/Tests/Unit/FIRTestCase.h"

#import "FirebaseCore/Extension/FIRSceneDelegateFinder.h"

@interface MockSceneDelegate : NSObject <UISceneDelegate>
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity;
@end

@implementation MockSceneDelegate
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
}
@end

@interface FIRSceneDelegateFinderTests : FIRTestCase
@property(nonatomic, strong) id mockApplication;
@end

@implementation FIRSceneDelegateFinderTests

- (void)setUp {
  [super setUp];
  self.mockApplication = OCMClassMock([UIApplication class]);
}

- (void)tearDown {
  [self.mockApplication stopMocking];
  [super tearDown];
}

- (void)testNilApplicationReturnsNil {
  UIScene *result = [FIRSceneDelegateFinder
      findForegroundSceneForApplication:nil
                       matchingSelector:@selector(scene:continueUserActivity:)];
  XCTAssertNil(result);
}

- (void)testNoMatchingScene {
  id mockScene = OCMClassMock([UIScene class]);
  OCMStub([mockScene activationState]).andReturn(UISceneActivationStateForegroundActive);
  // Delegate does NOT respond to target selector
  id mockDelegate = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMStub([mockScene delegate]).andReturn(mockDelegate);

  NSSet *connectedScenes = [NSSet setWithObject:mockScene];
  OCMStub([self.mockApplication connectedScenes]).andReturn(connectedScenes);

  UIScene *result = [FIRSceneDelegateFinder
      findForegroundSceneForApplication:self.mockApplication
                       matchingSelector:@selector(scene:continueUserActivity:)];
  XCTAssertNil(result);
}

- (void)testForegroundInactiveFallback {
  // Scene A is background
  id mockSceneA = OCMClassMock([UIScene class]);
  OCMStub([mockSceneA activationState]).andReturn(UISceneActivationStateBackground);
  id mockDelegateA = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneA delegate]).andReturn(mockDelegateA);

  // Scene B is foreground inactive (implements selector)
  id mockSceneB = OCMClassMock([UIScene class]);
  OCMStub([mockSceneB activationState]).andReturn(UISceneActivationStateForegroundInactive);
  id mockDelegateB = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneB delegate]).andReturn(mockDelegateB);

  NSSet *connectedScenes = [NSSet setWithObjects:mockSceneA, mockSceneB, nil];
  OCMStub([self.mockApplication connectedScenes]).andReturn(connectedScenes);

  UIScene *result = [FIRSceneDelegateFinder
      findForegroundSceneForApplication:self.mockApplication
                       matchingSelector:@selector(scene:continueUserActivity:)];
  XCTAssertEqual(result, mockSceneB);
}

- (void)testForegroundActivePriority {
  // Scene A is foreground inactive
  id mockSceneA = OCMClassMock([UIScene class]);
  OCMStub([mockSceneA activationState]).andReturn(UISceneActivationStateForegroundInactive);
  id mockDelegateA = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneA delegate]).andReturn(mockDelegateA);

  // Scene B is foreground active
  id mockSceneB = OCMClassMock([UIScene class]);
  OCMStub([mockSceneB activationState]).andReturn(UISceneActivationStateForegroundActive);
  id mockDelegateB = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneB delegate]).andReturn(mockDelegateB);

  NSSet *connectedScenes = [NSSet setWithObjects:mockSceneA, mockSceneB, nil];
  OCMStub([self.mockApplication connectedScenes]).andReturn(connectedScenes);

  UIScene *result = [FIRSceneDelegateFinder
      findForegroundSceneForApplication:self.mockApplication
                       matchingSelector:@selector(scene:continueUserActivity:)];
  XCTAssertEqual(result, mockSceneB);
}

- (void)testActiveSceneWithKeyWindowPriority {
  // Scene A is foreground active (window is not key)
  id mockWindowA = OCMClassMock([UIWindow class]);
  OCMStub([mockWindowA isKeyWindow]).andReturn(NO);
  id mockSceneA = OCMClassMock([UIWindowScene class]);
  OCMStub([mockSceneA activationState]).andReturn(UISceneActivationStateForegroundActive);
  OCMStub([mockSceneA windows]).andReturn(@[ mockWindowA ]);
  id mockDelegateA = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneA delegate]).andReturn(mockDelegateA);

  // Scene B is foreground active (window IS key)
  id mockWindowB = OCMClassMock([UIWindow class]);
  OCMStub([mockWindowB isKeyWindow]).andReturn(YES);
  id mockSceneB = OCMClassMock([UIWindowScene class]);
  OCMStub([mockSceneB activationState]).andReturn(UISceneActivationStateForegroundActive);
  OCMStub([mockSceneB windows]).andReturn(@[ mockWindowB ]);
  id mockDelegateB = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneB delegate]).andReturn(mockDelegateB);

  NSSet *connectedScenes = [NSSet setWithObjects:mockSceneA, mockSceneB, nil];
  OCMStub([self.mockApplication connectedScenes]).andReturn(connectedScenes);

  UIScene *result = [FIRSceneDelegateFinder
      findForegroundSceneForApplication:self.mockApplication
                       matchingSelector:@selector(scene:continueUserActivity:)];
  XCTAssertEqual(result, mockSceneB);
}

- (void)testInactiveSceneWithKeyWindowPriority {
  // Scene A is foreground inactive (window is not key)
  id mockWindowA = OCMClassMock([UIWindow class]);
  OCMStub([mockWindowA isKeyWindow]).andReturn(NO);
  id mockSceneA = OCMClassMock([UIWindowScene class]);
  OCMStub([mockSceneA activationState]).andReturn(UISceneActivationStateForegroundInactive);
  OCMStub([mockSceneA windows]).andReturn(@[ mockWindowA ]);
  id mockDelegateA = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneA delegate]).andReturn(mockDelegateA);

  // Scene B is foreground inactive (window IS key)
  id mockWindowB = OCMClassMock([UIWindow class]);
  OCMStub([mockWindowB isKeyWindow]).andReturn(YES);
  id mockSceneB = OCMClassMock([UIWindowScene class]);
  OCMStub([mockSceneB activationState]).andReturn(UISceneActivationStateForegroundInactive);
  OCMStub([mockSceneB windows]).andReturn(@[ mockWindowB ]);
  id mockDelegateB = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneB delegate]).andReturn(mockDelegateB);

  NSSet *connectedScenes = [NSSet setWithObjects:mockSceneA, mockSceneB, nil];
  OCMStub([self.mockApplication connectedScenes]).andReturn(connectedScenes);

  UIScene *result = [FIRSceneDelegateFinder
      findForegroundSceneForApplication:self.mockApplication
                       matchingSelector:@selector(scene:continueUserActivity:)];
  XCTAssertEqual(result, mockSceneB);
}

- (void)testActiveWithoutKeyWindowBeatsInactiveWithKeyWindow {
  // Scene A is foreground active (window is not key)
  id mockWindowA = OCMClassMock([UIWindow class]);
  OCMStub([mockWindowA isKeyWindow]).andReturn(NO);
  id mockSceneA = OCMClassMock([UIWindowScene class]);
  OCMStub([mockSceneA activationState]).andReturn(UISceneActivationStateForegroundActive);
  OCMStub([mockSceneA windows]).andReturn(@[ mockWindowA ]);
  id mockDelegateA = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneA delegate]).andReturn(mockDelegateA);

  // Scene B is foreground inactive (window IS key)
  id mockWindowB = OCMClassMock([UIWindow class]);
  OCMStub([mockWindowB isKeyWindow]).andReturn(YES);
  id mockSceneB = OCMClassMock([UIWindowScene class]);
  OCMStub([mockSceneB activationState]).andReturn(UISceneActivationStateForegroundInactive);
  OCMStub([mockSceneB windows]).andReturn(@[ mockWindowB ]);
  id mockDelegateB = OCMClassMock([MockSceneDelegate class]);
  OCMStub([mockSceneB delegate]).andReturn(mockDelegateB);

  NSSet *connectedScenes = [NSSet setWithObjects:mockSceneA, mockSceneB, nil];
  OCMStub([self.mockApplication connectedScenes]).andReturn(connectedScenes);

  UIScene *result = [FIRSceneDelegateFinder
      findForegroundSceneForApplication:self.mockApplication
                       matchingSelector:@selector(scene:continueUserActivity:)];
  XCTAssertEqual(result, mockSceneA);
}

@end

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
