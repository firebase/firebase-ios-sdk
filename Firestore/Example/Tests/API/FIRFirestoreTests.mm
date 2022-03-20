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

#import <FirebaseFirestore/FIRFirestore.h>
#import <FirebaseFirestore/FIRFirestoreSettings.h>

#import <XCTest/XCTest.h>

#import "FirebaseCore/Extension/FIRAppInternal.h"

#include "Firestore/core/test/unit/testutil/app_testing.h"

using firebase::firestore::testutil::AppForUnitTesting;

@interface FIRFirestoreTests : XCTestCase
@end

@implementation FIRFirestoreTests

- (void)testDeleteApp {
  // Ensure the app is set appropriately.
  FIRApp *app = AppForUnitTesting();
  NSString *appName = app.name;
  FIROptions *options = app.options;

  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];
  XCTAssertEqualObjects(firestore.app, app);

  // Ensure that firestoreForApp returns the same instance.
  XCTAssertEqualObjects(firestore, [FIRFirestore firestoreForApp:app]);

  XCTestExpectation *defaultAppDeletedExpectation =
      [self expectationWithDescription:@"Deleting the default app should invalidate the default "
                                       @"Firestore instance."];
  [app deleteApp:^(BOOL success) {
    XCTAssertTrue(success);

    // Recreate the FIRApp with the same name, fetch a new Firestore instance and make sure it's
    // different than the other one.
    [FIRApp configureWithName:appName options:options];
    FIRApp *newApp = [FIRApp appNamed:appName];
    FIRFirestore *newInstance = [FIRFirestore firestoreForApp:newApp];
    XCTAssertNotEqualObjects(newInstance, firestore);

    [defaultAppDeletedExpectation fulfill];
  }];

  [self waitForExpectationsWithTimeout:2
                               handler:^(NSError *_Nullable error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testSetEmulatorSettingsSetsHost {
  // Ensure the app is set appropriately.
  FIRApp *app = AppForUnitTesting();

  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];

  [firestore useEmulatorWithHost:@"localhost" port:1000];

  NSString *host = firestore.settings.host;
  XCTAssertEqualObjects(host, @"localhost:1000");
}

@end
