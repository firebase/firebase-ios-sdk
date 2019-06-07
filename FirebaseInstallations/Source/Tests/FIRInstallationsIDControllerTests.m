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

#import <OCMock/OCMock.h>
#import "FBLPromise+Testing.h"
#import "FIRInstallationsItem+Tests.h"

#import "FIRInstallationsIDController.h"
#import "FIRInstallationsStore.h"
#import "FIRInstallationsErrorUtil.h"

@interface FIRInstallationsIDController (Tests)
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                 installationsStore:(FIRInstallationsStore *)installationsStore;
@end

@interface FIRInstallationsIDControllerTests : XCTestCase
@property(nonatomic) FIRInstallationsIDController *controller;
@property(nonatomic) id mockInstallationsStore;
@property(nonatomic) NSString *appID;
@property(nonatomic) NSString *appName;
@end

@implementation FIRInstallationsIDControllerTests

- (void)setUp {
  self.appID = @"appID";
  self.appName = @"appName";
  self.mockInstallationsStore = OCMClassMock([FIRInstallationsStore class]);
  self.controller = [[FIRInstallationsIDController alloc] initWithGoogleAppID:self.appID
                                                                      appName:self.appName
                                                           installationsStore:self.mockInstallationsStore];
}

- (void)tearDown {
  self.controller = nil;
  self.mockInstallationsStore = nil;
  self.appID = nil;
  self.appName = nil;
}

- (void)testGetInstallationItem_WhenFIDExists_ThenItIsReturned {
  FIRInstallationsItem *storedInstallations = [FIRInstallationsItem createValidInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
  .andReturn([FBLPromise resolvedWith:storedInstallations]);

  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertEqual(promise.value, storedInstallations);

  OCMVerifyAll(self.mockInstallationsStore);
}

- (void)testGetInstallationItem_WhenNoFIDAndNoIID_ThenFIDIsCreated {
  // Stub get installation.
  NSError *notFoundError =
      [FIRInstallationsErrorUtil installationItemNotFoundForAppID:self.appID appName:self.appName];
  FBLPromise *installationNotFoundPromise = [FBLPromise pendingPromise];
  [installationNotFoundPromise reject:notFoundError];

  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
  .andReturn(installationNotFoundPromise);

  // Stub save installation.
  __block FIRInstallationsItem *installationToSave;

  OCMExpect([self.mockInstallationsStore saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
    XCTAssertEqualObjects([obj class], [FIRInstallationsItem class]);
    XCTAssertEqualObjects(obj.appID, self.appID);
    XCTAssertEqualObjects(obj.firebaseAppName, self.appName);
    XCTAssertEqual(obj.registrationStatus, FIRInstallationStatusUnregistered);
    XCTAssertNotNil(obj.firebaseInstallationID);

    installationToSave = obj;
    return YES;
  }]])
  .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // Call get installation and check.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertEqual(promise.value, installationToSave);

  OCMVerifyAll(self.mockInstallationsStore);
}

@end
