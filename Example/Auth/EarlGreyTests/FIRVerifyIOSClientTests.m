/*
 * Copyright 2018 Google
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

#import <XCTest/XCTest.h>
#import <EarlGrey/EarlGrey.h>
#import <FirebaseCore/FIRApp.h>
#import "FirebaseAuth.h"

static CGFloat const kShortScrollDistance = 100;

static NSTimeInterval const kWaitForElementTimeOut = 15;

@interface FIRVerifyIOSClientTests : XCTestCase
@end

/** Convenience function for EarlGrey tests. */
static id<GREYMatcher> grey_scrollView(void) {
  return [GREYMatchers matcherForKindOfClass:[UIScrollView class]];
}

@implementation FIRVerifyIOSClientTests

/** To reset the app so that each test sees the app in a clean state. */
- (void)setUp {
  [super setUp];

  [self signOut];

  [[EarlGrey selectElementWithMatcher:grey_allOf(grey_scrollView(),
                                                 grey_kindOfClass([UITableView class]), nil)]
                        performAction:grey_scrollToContentEdge(kGREYContentEdgeTop)];
}

#pragma mark - Tests

/** Test verify ios client*/
- (void)testVerifyIOSClient {
  [[[EarlGrey selectElementWithMatcher:grey_allOf(grey_text(@"Verify iOS client"),
                                                  grey_sufficientlyVisible(), nil)]
    usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, kShortScrollDistance)
    onElementWithMatcher:grey_allOf(grey_scrollView(), grey_kindOfClass([UITableView class]),
                                    nil)] performAction:grey_tap()];

  [self waitForElementWithText:@"OK" withDelay:kWaitForElementTimeOut];

  [[EarlGrey selectElementWithMatcher:grey_text(@"OK")] performAction:grey_tap()];
}

#pragma mark - Helpers

/** Sign out current account. */
- (void)signOut {
  NSError *signOutError;
  BOOL status = [[FIRAuth auth] signOut:&signOutError];

  // Just log the error because we don't want to fail the test if signing out fails.
  if (!status) {
    NSLog(@"Error signing out: %@", signOutError);
  }
}

/** Wait for an element with text to appear. */
- (void)waitForElementWithText:(NSString *)text withDelay:(NSTimeInterval)maxDelay {
  GREYCondition *displayed =
  [GREYCondition conditionWithName:@"Wait for element"
                             block:^BOOL {
                               NSError *error = nil;
                               [[EarlGrey selectElementWithMatcher:grey_text(text)]
                                assertWithMatcher:grey_sufficientlyVisible()
                                            error:&error];
                               return !error;
                             }];
  GREYAssertTrue([displayed waitWithTimeout:maxDelay], @"Failed to wait for element '%@'.", text);
}

@end
