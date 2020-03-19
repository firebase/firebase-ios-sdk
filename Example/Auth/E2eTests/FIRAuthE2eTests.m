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

#import "FIRAuthE2eTestsBase.h"

@interface FIRAuthE2eTests : FIRAuthE2eTestsBase

@end

@implementation FIRAuthE2eTests

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
                 // TODO: Add accessibilityIdentifiers for the elements.
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

@end
