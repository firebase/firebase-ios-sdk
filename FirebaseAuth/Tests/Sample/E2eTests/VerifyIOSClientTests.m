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

#import "FIRAuthE2eTestsBase.h"

@interface VerifyIOSClientTests : FIRAuthE2eTestsBase

@end

@implementation VerifyIOSClientTests

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

@end
