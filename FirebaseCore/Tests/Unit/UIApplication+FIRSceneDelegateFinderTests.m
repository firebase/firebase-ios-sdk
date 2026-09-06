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

#import "FirebaseCore/Extension/UIApplication+FIRSceneDelegateFinder.h"

@interface MockSceneDelegate : NSObject <UISceneDelegate>
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity;
@end

@implementation MockSceneDelegate
- (void)scene:(UIScene *)scene continueUserActivity:(NSUserActivity *)userActivity {
}
@end

@interface UIApplication_FIRSceneDelegateFinderTests : FIRTestCase
@property(nonatomic, strong) id mockApplication;
@end

@implementation UIApplication_FIRSceneDelegateFinderTests

- (void)setUp {
  [super setUp];
  self.mockApplication = OCMClassMock([UIApplication class]);
}

- (void)tearDown {
  [self.mockApplication stopMocking];
  [super tearDown];
}

- (void)testNoMatchingScene {
  id mockScene = OCMClassMock([UIScene class]);
  OCMStub([mockScene activationState]).andReturn(UISceneActivationStateForegroundActive);
  // Delegate does NOT respond to target selector
  id mockDelegate = OCMProtocolMock(@protocol(UIApplicationDelegate));
  OCMStub([mockScene delegate]).andReturn(mockDelegate);

  NSSet *connectedScenes = [NSSet setWithObject:mockScene];
  OCMStub([self.mockApplication connectedScenes]).andReturn(connectedScenes);

  UIScene *result = [UIApplication
      fir_findForegroundSceneWithDelegateRespondingToSelector:@selector(scene:continueUserActivity:)
                                                onApplication:self.mockApplication];
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

  UIScene *result = [UIApplication
      fir_findForegroundSceneWithDelegateRespondingToSelector:@selector(scene:continueUserActivity:)
                                                onApplication:self.mockApplication];
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

  UIScene *result = [UIApplication
      fir_findForegroundSceneWithDelegateRespondingToSelector:@selector(scene:continueUserActivity:)
                                                onApplication:self.mockApplication];
  XCTAssertEqual(result, mockSceneB);
}

@end

#endif  // TARGET_OS_IOS || TARGET_OS_TV || TARGET_OS_VISION
