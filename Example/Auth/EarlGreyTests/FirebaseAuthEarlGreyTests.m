/*
 * Copyright 2017 Google
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

#import <EarlGrey/EarlGrey.h>
#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import <FirebaseCore/FIRApp.h>
#import "FirebaseAuth.h"

#ifdef NO_NETWORK
#import "ioReplayer/IORTestCase.h"
#endif

/** The url for obtaining a valid custom token string used to test BYOAuth. */
static NSString *const kCustomTokenUrl = @"https://fb-sa-1211.appspot.com/token";

/** The invalid custom token string for testing BYOAuth. */
static NSString *const kInvalidCustomToken = @"invalid token.";

/** The user name string for BYOAuth testing account. */
static NSString *const kTestingAccountUserID = @"BYU_Test_User_ID";

static CGFloat const kShortScrollDistance = 100;

static NSTimeInterval const kWaitForElementTimeOut = 5;

#ifdef NO_NETWORK
@interface BasicUITest : IORTestCase
#else
@interface BasicUITest :XCTestCase
#endif
@end

/** Convenience function for EarlGrey tests. */
id<GREYMatcher> grey_scrollView(void) {
  return [GREYMatchers matcherForKindOfClass:[UIScrollView class]];
}

@implementation BasicUITest

/** To reset the app so that each test sees the app in a clean state. */
- (void)setUp {
  [super setUp];

  [self signOut];

  [[EarlGrey selectElementWithMatcher:grey_allOf(grey_scrollView(),
                                                 grey_kindOfClass([UITableView class]), nil)]
      performAction:grey_scrollToContentEdge(kGREYContentEdgeTop)];
}

#pragma mark - Tests

/**
 * This test runs in replay mode by default. To run in a different mode
 * follow the instructions below.
 *
 * Blaze:
 * --test_arg=\'--networkReplayMode=(replay|record|disabled|observe)\'
 *
 * Xcode:
 * Update the following flag in the xcscheme.
 * --networkReplayMode=(replay|record|disabled|observe)
 */
- (void)testSignInExistingUser {
  NSString *email = @"123@abc.com";
  [[[EarlGrey selectElementWithMatcher:grey_allOf(grey_text(@"Sign in with Email/Password"),
                                                  grey_sufficientlyVisible(), nil)]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, kShortScrollDistance)
      onElementWithMatcher:grey_allOf(grey_scrollView(), grey_kindOfClass([UITableView class]),
                                      nil)] performAction:grey_tap()];

  id<GREYMatcher> comfirmationButtonMatcher =
      grey_allOf(grey_kindOfClass([UILabel class]), grey_accessibilityLabel(@"OK"), nil);

  [[EarlGrey selectElementWithMatcher:
      #warning TODO Add accessibilityIdentifiers for the elements.
      grey_kindOfClass(NSClassFromString(@"_UIAlertControllerView"))]
      performAction:grey_typeText(email)];

  [[EarlGrey selectElementWithMatcher:comfirmationButtonMatcher] performAction:grey_tap()];

  [[EarlGrey
      selectElementWithMatcher:grey_kindOfClass(NSClassFromString(@"_UIAlertControllerView"))]
      performAction:grey_typeText(@"password")];

  [[EarlGrey selectElementWithMatcher:comfirmationButtonMatcher] performAction:grey_tap()];

  [[[EarlGrey
      selectElementWithMatcher:grey_allOf(grey_text(email), grey_sufficientlyVisible(), nil)]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionUp, kShortScrollDistance)
      onElementWithMatcher:grey_allOf(grey_scrollView(), grey_kindOfClass([UITableView class]),
                                      nil)] assertWithMatcher:grey_sufficientlyVisible()];
}

/** Test sign in with a valid BYOAuth token retrived from a remote server. */
- (void)testSignInWithValidBYOAuthToken {
  NSError *error;
  NSString *customToken = [NSString stringWithContentsOfURL:[NSURL URLWithString:kCustomTokenUrl]
                                                   encoding:NSUTF8StringEncoding
                                                      error:&error];
  if (!customToken) {
    GREYFail(@"There was an error retrieving the custom token: %@", error);
  }

  [[[EarlGrey selectElementWithMatcher:grey_allOf(grey_text(@"Sign In (BYOAuth)"),
                                                  grey_sufficientlyVisible(), nil)]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, kShortScrollDistance)
      onElementWithMatcher:grey_allOf(grey_scrollView(), grey_kindOfClass([UITableView class]),
                                      nil)] performAction:grey_tap()];

  [[[EarlGrey selectElementWithMatcher:grey_kindOfClass([UITextView class])]
      performAction:grey_replaceText(customToken)] assertWithMatcher:grey_text(customToken)];

  [[EarlGrey selectElementWithMatcher:grey_text(@"Done")] performAction:grey_tap()];

  [self waitForElementWithText:@"OK" withDelay:kWaitForElementTimeOut];

  [[EarlGrey selectElementWithMatcher:grey_text(@"OK")] performAction:grey_tap()];

  [[[EarlGrey
      selectElementWithMatcher:grey_allOf(grey_text(kTestingAccountUserID),
                                          grey_sufficientlyVisible(), nil)]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionUp,
                                                  kShortScrollDistance)
      onElementWithMatcher:grey_allOf(grey_scrollView(),
                                      grey_kindOfClass([UITableView class]),
                                      nil)]
      assertWithMatcher:grey_sufficientlyVisible()];
}

- (void)testSignInWithInvalidBYOAuthToken {
  [[[EarlGrey selectElementWithMatcher:grey_allOf(grey_text(@"Sign In (BYOAuth)"),
                                                  grey_sufficientlyVisible(), nil)]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionDown, kShortScrollDistance)
      onElementWithMatcher:grey_allOf(grey_scrollView(), grey_kindOfClass([UITableView class]),
                                      nil)] performAction:grey_tap()];

  [[[EarlGrey selectElementWithMatcher:grey_kindOfClass([UITextView class])]
      performAction:grey_replaceText(kInvalidCustomToken)]
      assertWithMatcher:grey_text(kInvalidCustomToken)];

  [[EarlGrey selectElementWithMatcher:grey_text(@"Done")] performAction:grey_tap()];

  NSString *invalidTokenErrorMessage =
      @"The custom token format is incorrect. Please check the documentation.";

  [self waitForElementWithText:invalidTokenErrorMessage withDelay:kWaitForElementTimeOut];

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
