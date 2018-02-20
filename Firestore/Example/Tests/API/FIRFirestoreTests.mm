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

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIROptionsInternal.h>
#import <FirebaseFirestore/FIRFirestore.h>

#import <XCTest/XCTest.h>

@interface FIRFirestoreTests : XCTestCase
@end

@implementation FIRFirestoreTests

- (void)testDeleteApp {
  // Create a FIRApp for testing.
  NSString *appName = @"custom_app_name";
  FIROptions *options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123ab" GCMSenderID:@"gcm_sender_id"];
  options.projectID = @"project_id";
  [FIRApp configureWithName:appName options:options];

  // Ensure the app is set appropriately.
  FIRApp *app = [FIRApp appNamed:appName];
  FIRFirestore *firestore = [FIRFirestore firestoreForApp:app];
  XCTAssertEqualObjects(firestore.app, app);

  // Ensure that firestoreForApp returns the same instance.
  XCTAssertEqualObjects(firestore, [FIRFirestore firestoreForApp:app]);

  XCTestExpectation *defaultAppDeletedExpectation =
      [self expectationWithDescription:
                @"Deleting the default app should invalidate the default "
                @"Firestore instance."];
  [app deleteApp:^(BOOL success) {
    // Recreate the FIRApp with the same name, fetch a new Firestore instance and make sure it's
    // different than the other one.
    [FIRApp configureWithName:appName options:options];
    FIRApp *newApp = [FIRApp appNamed:appName];
    FIRFirestore *newInstance = [FIRFirestore firestoreForApp:newApp];
    XCTAssertNotEqualObjects(newInstance, firestore);

    [defaultAppDeletedExpectation fulfill];
  }];

  [self waitForExpectations:@[ defaultAppDeletedExpectation ] timeout:2];
}

@end
