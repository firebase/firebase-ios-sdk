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

#import <XCTest/XCTest.h>

#import <EarlGrey/EarlGrey.h>

#import <FirebaseAuth/FirebaseAuth.h>

NS_ASSUME_NONNULL_BEGIN

extern CGFloat const kShortScrollDistance;

extern NSTimeInterval const kWaitForElementTimeOut;

/** Convenience function for EarlGrey tests. */
id<GREYMatcher> grey_scrollView(void);

@interface FIRAuthE2eTestsBase : XCTestCase

/** Sign out current account. */
- (void)signOut;

/** Wait for an element with text to appear. */
- (void)waitForElementWithText:(NSString *)text withDelay:(NSTimeInterval)maxDelay;

@end

NS_ASSUME_NONNULL_END
