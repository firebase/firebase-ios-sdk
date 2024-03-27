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

#import <FirebaseAuth/FirebaseAuth.h>
#import <FirebaseCore/FIRApp.h>
#import "AuthCredentials.h"

#ifdef NO_NETWORK
#import "ITUIOSTestUtil.h"
#endif

#import <GTMSessionFetcher/GTMSessionFetcher.h>
#import <GTMSessionFetcher/GTMSessionFetcherService.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef NO_NETWORK
#define SKIP_IF_ON_MOBILE_HARNESS                                          \
  if ([ITUIOSTestUtil isOnMobileHarness]) {                                \
    NSLog(@"Skipping '%@' on mobile harness", NSStringFromSelector(_cmd)); \
    return;                                                                \
  }
#else
#define SKIP_IF_ON_MOBILE_HARNESS
#endif

static NSTimeInterval const kExpectationsTimeout = 10;

@interface FIRAuthApiTestsBase : XCTestCase

/** Sign in anonymously. */
- (void)signInAnonymously;

/** Sign out current account. */
- (void)signOut;

/** Clean up the created user for tests' future runs. */
- (void)deleteCurrentUser;

/** Generate fake random email address */
- (NSString *)fakeRandomEmail;

@end

NS_ASSUME_NONNULL_END
