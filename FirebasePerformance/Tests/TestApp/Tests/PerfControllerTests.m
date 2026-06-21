// Copyright 2020 Google LLC
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

// Non-google3 relative import to support building with Xcode.
#import "../Source/ViewControllers/NetworkConnectionViewController+Accessibility.h"
#import "../Source/ViewControllers/NetworkRequestsViewController.h"
#import "../Source/ViewControllers/TracesViewController+Accessibility.h"
#import "../Source/ViewControllers/TracesViewController.h"
#import "../Source/Views/PerfTraceView+Accessibility.h"
#import "third_party/objective_c/EarlGreyV2/TestLib/EarlGreyImpl/EarlGrey.h"

const NSUInteger kStagesCount = 10;
const NSUInteger kCounterTaps = 10;
const NSUInteger kRequestsCount = 5;
static NSString *const kTraceName = @"Trace 1";

@interface PerfControllerTests : XCTestCase

- (void)tapStageButtonNTimes:(NSUInteger)tapsCount;
- (void)tapCountButtonsNTimes:(NSUInteger)tapsCount;

@end

@implementation PerfControllerTests {
  XCUIApplication *_application;
}

#pragma mark - Test cases

- (void)setUp {
  [super setUp];
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _application = [[XCUIApplication alloc] init];
    [_application launch];
  });
}

- (void)testKeyWindow {
  [[EarlGrey selectElementWithMatcher:grey_keyWindow()]
      assertWithMatcher:grey_sufficientlyVisible()];
}

- (void)testTraceStages {
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(@"TracesTab")] performAction:grey_tap()];

  NSString *addTraceAccessibilityId =
      [GREY_REMOTE_CLASS_IN_APP(TracesViewController) addTraceAccessibilityItem].accessibilityID;

  [self tapElementWithMatcher:grey_accessibilityID(addTraceAccessibilityId)];

  [self tapStageButtonNTimes:kStagesCount];

  [self tapCountButtonsNTimes:kCounterTaps];

  NSString *stopAccessibilityId =
      [GREY_REMOTE_CLASS_IN_APP(PerfTraceView) stopAccessibilityItemWithTraceName:kTraceName]
          .accessibilityID;

  [self tapElementWithMatcher:grey_accessibilityID(stopAccessibilityId)];
}

- (void)testPerfURLConnectionWithDelegateClassInit {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLConnectionWithDelegateClassInit"];
}

- (void)testPerfURLConnectionWithDelegate {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLConnectionWithDelegate"];
}

- (void)testPerfURLConnectionWithDelegateStartImmediately {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLConnectionWithDelegateStartImmediately"];
}

- (void)testPerfURLConnectionAsyncRequest {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLConnectionAsyncRequest"];
}

- (void)testPerfURLSessionDownloadTaskWithDelegate {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLSessionDownloadTaskWithDelegate"];
}

- (void)testPerfURLSessionDataTaskWithDelegate {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLSessionDataTaskWithDelegate"];
}

- (void)testPerfURLSessionDownloadTask {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLSessionDownloadTask"];
}

- (void)testPerfURLSessionDataTask {
  [self tapAndCheckConnectionTypeWithName:@"PerfURLSessionDataTask"];
}

#pragma mark - Private methods

- (void)tapAndCheckConnectionTypeWithName:(NSString *)connectionName {
  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(@"RequestsTab")]
      performAction:grey_tap()];

  NSString *conditionName =
      [NSString stringWithFormat:@"Check if %@ button visible", connectionName];
  GREYCondition *conditionForElement = [GREYCondition
      conditionWithName:conditionName
                  block:^BOOL {
                    NSError *error;
                    [[EarlGrey selectElementWithMatcher:grey_buttonTitle(connectionName)]
                        assertWithMatcher:grey_sufficientlyVisible()
                                    error:&error];
                    return (error == nil);
                  }];

  BOOL elementAppeared = [conditionForElement waitWithTimeout:1];

  if (!elementAppeared) {
    GREYElementInteraction *scrollViewInteractor =
        [EarlGrey selectElementWithMatcher:grey_accessibilityID(@"RequestsScrollView")];
    [scrollViewInteractor performAction:grey_swipeFastInDirection(kGREYDirectionUp)];
  }

  [self tapElementWithMatcher:grey_buttonTitle(connectionName)];

  AccessibilityItem *item = [GREY_REMOTE_CLASS_IN_APP(NetworkConnectionViewController)
      statusLabelAccessibilityItemWithConnectionName:connectionName];

  BOOL (^conditionBlock)(void) = ^BOOL {
    NSError *error = nil;
    [[EarlGrey selectElementWithMatcher:grey_accessibilityID(item.accessibilityID)]
        assertWithMatcher:grey_anyOf(grey_text(@"Success"), grey_text(@"Fail"), nil)
                    error:&error];
    if (error) {
      NSLog(@"EarlGrey synchronization: status label hasn't been updated yet");
    }
    return error == nil;
  };

  BOOL succeeded = [[GREYCondition conditionWithName:@"Wait for status label to change text"
                                               block:conditionBlock] waitWithTimeout:30];
  XCTAssertTrue(succeeded);

  [[EarlGrey selectElementWithMatcher:grey_accessibilityID(item.accessibilityID)]
      assertWithMatcher:grey_text(@"Success")];
}

- (void)tapCountButtonsNTimes:(NSUInteger)tapsCount {
  for (int counterTapNumber = 0; counterTapNumber < tapsCount; counterTapNumber++) {
    NSString *counterAccessibilityID = counterTapNumber % 2 == 1
                                           ? [GREY_REMOTE_CLASS_IN_APP(PerfTraceView)
                                                 metricOneAccessibilityItemWithTraceName:kTraceName]
                                                 .accessibilityID
                                           : [GREY_REMOTE_CLASS_IN_APP(PerfTraceView)
                                                 metricTwoAccessibilityItemWithTraceName:kTraceName]
                                                 .accessibilityID;
    [self tapElementWithMatcher:grey_accessibilityID(counterAccessibilityID)];
  }
}

- (void)tapElementWithMatcher:(id<GREYMatcher>)matcher {
  [[EarlGrey selectElementWithMatcher:matcher] performAction:grey_tap()];
}

- (void)tapStageButtonNTimes:(NSUInteger)tapsCount {
  NSString *stageAccessibilityId =
      [GREY_REMOTE_CLASS_IN_APP(PerfTraceView) stageAccessibilityItemWithTraceName:kTraceName]
          .accessibilityID;

  for (int stageNumber = 0; stageNumber < tapsCount; stageNumber++) {
    [self tapElementWithMatcher:grey_accessibilityID(stageAccessibilityId)];
  }
}

@end
