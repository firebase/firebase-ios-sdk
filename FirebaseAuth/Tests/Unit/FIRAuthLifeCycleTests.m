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

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "Interop/Auth/Public/FIRAuthInterop.h"

#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthRequestConfiguration.h"
#import "FirebaseAuth/Tests/Unit/FIRApp+FIRAuthUnitTests.h"

/** @var kFirebaseAppName1
    @brief A fake Firebase app name.
 */
static NSString *const kFirebaseAppName1 = @"FIREBASE_APP_NAME_1";

/** @var kFirebaseAppName2
    @brief Another fake Firebase app name.
 */
static NSString *const kFirebaseAppName2 = @"FIREBASE_APP_NAME_2";

/** @var kAPIKey
    @brief The fake API key.
 */
static NSString *const kAPIKey = @"FAKE_API_KEY";

/** @var kExpectationTimeout
    @brief The maximum time waiting for expectations to fulfill.
 */
static const NSTimeInterval kExpectationTimeout = 2;

/** @var kWaitInterval
    @brief The time waiting for background tasks to finish before continue when necessary.
 */
static const NSTimeInterval kWaitInterval = .5;

@interface FIRAuthLifeCycleTests : XCTestCase

@end

@implementation FIRAuthLifeCycleTests

- (void)setUp {
  [super setUp];

  [FIRApp resetAppForAuthUnitTests];
}

- (void)tearDown {
  [super tearDown];
}

/** @fn testSingleton
    @brief Verifies the @c auth method behaves like a singleton.
 */
- (void)testSingleton {
  FIRAuth *auth1 = [FIRAuth auth];
  XCTAssertNotNil(auth1);
  FIRAuth *auth2 = [FIRAuth auth];
  XCTAssertEqual(auth1, auth2);
}

/** @fn testDefaultAuth
    @brief Verifies the @c auth method associates with the default Firebase app.
 */
- (void)testDefaultAuth {
  FIRAuth *auth1 = [FIRAuth auth];
  FIRAuth *auth2 = [FIRAuth authWithApp:[FIRApp defaultApp]];
  XCTAssertEqual(auth1, auth2);
  XCTAssertEqual(auth1.app, [FIRApp defaultApp]);
}

/** @fn testNilAppException
    @brief Verifies the @c auth method raises an exception if the default FIRApp is not configured.
 */
- (void)testNilAppException {
  [FIRApp resetApps];
  XCTAssertThrows([FIRAuth auth]);
}

/** @fn testAppAPIkey
    @brief Verifies the API key is correctly copied from @c FIRApp to @c FIRAuth .
 */
- (void)testAppAPIkey {
  FIRAuth *auth = [FIRAuth auth];
  XCTAssertEqualObjects(auth.requestConfiguration.APIKey, kAPIKey);
}

/** @fn testAppAssociation
    @brief Verifies each @c FIRApp instance associates with a @c FIRAuth .
 */
- (void)testAppAssociation {
  FIRApp *app1 = [self app1];
  FIRAuth *auth1 = [FIRAuth authWithApp:app1];
  XCTAssertNotNil(auth1);
  XCTAssertEqual(auth1.app, app1);

  FIRApp *app2 = [self app2];
  FIRAuth *auth2 = [FIRAuth authWithApp:app2];
  XCTAssertNotNil(auth2);
  XCTAssertEqual(auth2.app, app2);

  XCTAssertNotEqual(auth1, auth2);
}

/** @fn testLifeCycle
    @brief Verifies the life cycle of @c FIRAuth is the same as its associated @c FIRApp .
 */
- (void)testLifeCycle {
  __weak FIRApp *app;
  __weak FIRAuth *auth;
  @autoreleasepool {
    FIRApp *app1 = [self app1];
    app = app1;
    auth = [FIRAuth authWithApp:app1];
    // Verify that neither the app nor the auth is released yet, i.e., the app owns the auth
    // because nothing else retains the auth.
    XCTAssertNotNil(app);
    XCTAssertNotNil(auth);
  }
  [self waitForTimeIntervel:kWaitInterval];
  // Verify that both the app and the auth are released upon exit of the autorelease pool,
  // i.e., the app is the sole owner of the auth.
  XCTAssertNil(app);
  XCTAssertNil(auth);
}

/** @fn app1
    @brief Creates a Firebase app.
 @return A @c FIRApp with some name.
 */
- (FIRApp *)app1 {
  return [FIRApp appForAuthUnitTestsWithName:kFirebaseAppName1];
}

/** @fn app2
    @brief Creates another Firebase app.
 @return A @c FIRApp with some other name.
 */
- (FIRApp *)app2 {
  return [FIRApp appForAuthUnitTestsWithName:kFirebaseAppName2];
}

/** @fn waitForTimeInterval:
    @brief Wait for a particular time interval.
 @remarks This method also waits for all other pending @c XCTestExpectation instances.
 */
- (void)waitForTimeIntervel:(NSTimeInterval)timeInterval {
  static dispatch_queue_t queue;
  static dispatch_once_t onceToken;
  XCTestExpectation *expectation = [self expectationWithDescription:@"waitForTimeIntervel:"];
  dispatch_once(&onceToken, ^{
    queue = dispatch_queue_create("com.google.FIRAuthUnitTests.waitForTimeIntervel", NULL);
  });
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, timeInterval * NSEC_PER_SEC), queue, ^() {
    [expectation fulfill];
  });
  [self waitForExpectationsWithTimeout:timeInterval + kExpectationTimeout handler:nil];
}

@end
