/*
 * Copyright 2019 Google
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

#import "FIRAuthE2eTestsBase.h"

/** The url for obtaining a valid custom token string used to test BYOAuth. */
static NSString *const kCustomTokenUrl = @"https://gcip-testapps.wl.r.appspot.com/token";

/** The invalid custom token string for testing BYOAuth. */
static NSString *const kInvalidCustomToken = @"invalid token.";

/** The user name string for BYOAuth testing account. */
static NSString *const kTestingAccountUserID = @"BYU_Test_User_ID";

@interface BYOAuthTests : FIRAuthE2eTestsBase

@end

@implementation BYOAuthTests

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

  [[[EarlGrey selectElementWithMatcher:grey_allOf(grey_text(kTestingAccountUserID),
                                                  grey_sufficientlyVisible(), nil)]
         usingSearchAction:grey_scrollInDirection(kGREYDirectionUp, kShortScrollDistance)
      onElementWithMatcher:grey_allOf(grey_scrollView(), grey_kindOfClass([UITableView class]),
                                      nil)] assertWithMatcher:grey_sufficientlyVisible()];
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

  NSString *invalidTokenErrorMessage = @"Sign-In Error";

  [self waitForElementWithText:invalidTokenErrorMessage withDelay:kWaitForElementTimeOut];

  [[EarlGrey selectElementWithMatcher:grey_text(@"OK")] performAction:grey_tap()];
}

@end
