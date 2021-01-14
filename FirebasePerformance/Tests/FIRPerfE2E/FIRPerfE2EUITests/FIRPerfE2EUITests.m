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

// Time to wait for the traces test to finish.
static const NSTimeInterval kTestWaitTimeInSeconds = 12 * 60;

@interface FIRPerfE2EUITests : XCTestCase

@end

@implementation FIRPerfE2EUITests

XCUIApplication *_application;

- (void)setUp {
  [super setUp];

  // In UI tests it is usually best to stop immediately when a failure occurs.
  self.continueAfterFailure = NO;

  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _application = [[XCUIApplication alloc] init];

    // If the autopush environment variable is set, propagate this environment variable to the
    // underlying test app.
    NSDictionary<NSString *, NSString *> *environment = [NSProcessInfo processInfo].environment;
    if (environment[@"FPR_AUTOPUSH_ENV"] != nil &&
        [environment[@"FPR_AUTOPUSH_ENV"] isEqualToString:@"1"]) {
      _application.launchEnvironment = @{@"FPR_AUTOPUSH_ENV" : @"1"};
    }

    [_application launch];
  });
}

/** Runs all the tests related to traces (Traces + Network Requests + Screen traces). */
- (void)testTracesAndNetworkRequests {
  // Tap the start traces button
  XCUIElement *startTracesButton = _application.buttons[@"Start traces"];
  [startTracesButton tap];

  // Label denoting the pending traces.
  XCUIElement *label = [[_application staticTexts] elementMatchingType:XCUIElementTypeAny
                                                            identifier:@"Pending traces count - 0"];

  NSPredicate *existsPredicate = [NSPredicate predicateWithFormat:@"exists == true"];
  XCTestExpectation *expectation = [self expectationForPredicate:existsPredicate
                                             evaluatedWithObject:label
                                                         handler:^BOOL {
                                                           // Add a delay for the last set of traces
                                                           // to be uploaded.
                                                           [NSThread sleepForTimeInterval:30.0f];
                                                           return YES;
                                                         }];

  // Wait until the pending traces 0 count text is available.
  [self waitForExpectations:[[NSArray alloc] initWithObjects:expectation, nil]
                    timeout:kTestWaitTimeInSeconds];
}

- (void)testScreenTraces {
  // Tap the start screen traces button.
  XCUIElement *startScreenTracesButton = _application.buttons[@"Test screen traces"];
  [startScreenTracesButton tap];

  XCUIElementQuery *tablesQuery = _application.tables;

  // Perform 5 swipe up actions before going back.
  for (int i = 0; i < 5; i++) {
    [[tablesQuery element] swipeUp];
  }

  // Go back to main screen.
  [_application.navigationBars[@"PerfE2EScreenTracesView"].buttons[@"Back"] tap];
}

@end
