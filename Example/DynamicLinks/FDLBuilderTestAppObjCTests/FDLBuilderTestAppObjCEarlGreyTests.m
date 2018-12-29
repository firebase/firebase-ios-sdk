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

#ifdef COCOAPODS
#import <EarlGrey/EarlGrey.h>
#else
#import "third_party/objective_c/EarlGrey/EarlGrey/EarlGrey.h"
#endif

@interface FDLBuilderTestAppObjCEarlGreyTests : XCTestCase

@end

@implementation FDLBuilderTestAppObjCEarlGreyTests

#pragma mark - Tests

- (void)testOpenFDLFromAppGeneratedLink {
  // On first launch, a null FDL Received alert is displayed (by design); in
  // this case, we need to dismiss it in order to proceed
  BOOL hasFirstInstallAlertDisplayed = [self confirmPresenceOfFDLAlertWithURL:@"(null)"
                                                                    matchType:@"0"
                                                            minimumAppVersion:@"(null)"];
  if (hasFirstInstallAlertDisplayed) {
    [[EarlGrey selectElementWithMatcher:[GREYMatchers matcherForText:@"Dismiss"]]
        performAction:grey_tap()];
  }

  // Scroll down in the app until the Generate Link button can be pressed, then tap it
  [[[EarlGrey selectElementWithMatcher:[GREYMatchers matcherForText:@"Generate Link"]]
         usingSearchAction:grey_swipeFastInDirection(kGREYDirectionUp)
      onElementWithMatcher:grey_kindOfClass([UITableView class])] performAction:grey_tap()];

  // Find long link table view cell
  NSString *fdlLongLinkId = @"LinkTableViewCell-LinkTextView-Long link";

  // Find long link table view cell
  [[[EarlGrey selectElementWithMatcher:grey_accessibilityID(fdlLongLinkId)] atIndex:0]
      assert:[GREYAssertionBlock
                       assertionWithName:@"Long link non empty and valid"
                 assertionBlockWithError:^BOOL(id element, NSError *__strong *errorOrNil) {
                   XCTAssertTrue([element isKindOfClass:[UITextView class]]);
                   UITextView *longLinkTextView = element;
                   // ensure long link cell has non empty value
                   XCTAssertTrue(longLinkTextView.text.length > 0);
                   // ensure long link cell value is a valid URL
                   XCTAssertNotNil([NSURL URLWithString:longLinkTextView.text]);

                   return YES;
                 }]];
}

#pragma mark - Private

- (BOOL)waitForElementWithMatcher:(id<GREYMatcher>)matcher
            toBeVisibleWithinTime:(CFTimeInterval)timeInterval {
  return [[GREYCondition conditionWithName:@"Waiting for element to appear"
                                     block:^BOOL() {
                                       return [self isElementPresentWithMatcher:matcher];
                                     }] waitWithTimeout:timeInterval];
}

- (BOOL)isElementPresentWithMatcher:(id<GREYMatcher>)matcher {
  NSError *error = nil;

  [[[EarlGrey selectElementWithMatcher:matcher] atIndex:0] assertWithMatcher:grey_notNil()
                                                                       error:&error];

  if (error && (![error.domain isEqualToString:kGREYInteractionErrorDomain] ||
                error.code != kGREYInteractionElementNotFoundErrorCode)) {
    GREYFail(@"Unexpected error when trying to locate an element matching %@: %@", matcher, error);
  }
  return error == nil;
}

- (BOOL)confirmPresenceOfFDLAlertWithURL:(NSString *)URL
                               matchType:(NSString *)matchType
                       minimumAppVersion:(NSString *)minimumAppVersion {
  id<GREYMatcher> alertViewClass = grey_kindOfClass(NSClassFromString(@"_UIAlertControllerView"));
  NSString *expectedAlertText =
      [NSString stringWithFormat:@"URL [%@], matchType [%@], minimumAppVersion [%@]", URL,
                                 matchType, minimumAppVersion];

  return [self waitForElementWithMatcher:grey_allOf(grey_ancestor(alertViewClass),
                                                    grey_text(expectedAlertText), nil)
                   toBeVisibleWithinTime:10];
}

@end
