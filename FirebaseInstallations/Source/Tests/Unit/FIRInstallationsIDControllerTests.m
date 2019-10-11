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

#import <FirebaseCore/FIRAppInternal.h>

#import "FBLPromise+Testing.h"
#import "FIRInstallationsErrorUtil+Tests.h"
#import "FIRInstallationsItem+Tests.h"
#import "XCTestCase+DateAsserts.h"

#import "FIRInstallations.h"
#import "FIRInstallationsAPIService.h"
#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsHTTPError.h"
#import "FIRInstallationsIDController.h"
#import "FIRInstallationsIIDStore.h"
#import "FIRInstallationsStore.h"

#import "FIRInstallationsStoredAuthToken.h"
#import "FIRInstallationsStoredRegistrationError.h"
#import "FIRInstallationsStoredRegistrationParameters.h"

@interface FIRInstallationsIDController (Tests)
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                 installationsStore:(FIRInstallationsStore *)installationsStore
                         APIService:(FIRInstallationsAPIService *)APIService
                           IIDStore:(FIRInstallationsIIDStore *)IIDStore;
@end

@interface FIRInstallationsIDControllerTests : XCTestCase
@property(nonatomic) FIRInstallationsIDController *controller;
@property(nonatomic) id mockInstallationsStore;
@property(nonatomic) id mockAPIService;
@property(nonatomic) id mockIIDStore;
@property(nonatomic) NSString *appID;
@property(nonatomic) NSString *appName;

@property(nonatomic) NSString *APIKey;
@property(nonatomic) NSString *projectID;
@end

@implementation FIRInstallationsIDControllerTests

- (void)setUp {
  [self setUpWithAppName:kFIRDefaultAppName];
}

- (void)setUpWithAppName:(NSString *)appName {
  self.appID = @"appID";
  self.appName = appName;
  self.APIKey = @"APIKey";
  self.projectID = @"projectID";

  self.mockInstallationsStore = OCMStrictClassMock([FIRInstallationsStore class]);
  self.mockAPIService = OCMStrictClassMock([FIRInstallationsAPIService class]);
  self.mockIIDStore = OCMStrictClassMock([FIRInstallationsIIDStore class]);

  [self stubAPIServiceParameters];

  self.controller =
      [[FIRInstallationsIDController alloc] initWithGoogleAppID:self.appID
                                                        appName:self.appName
                                             installationsStore:self.mockInstallationsStore
                                                     APIService:self.mockAPIService
                                                       IIDStore:self.mockIIDStore];
}

- (void)tearDown {
  self.controller = nil;
  self.mockIIDStore = nil;
  self.mockAPIService = nil;
  self.mockInstallationsStore = nil;
  self.appID = nil;
  self.appName = nil;
}

- (void)stubAPIServiceParameters {
  OCMStub([self.mockAPIService APIKey]).andReturn(self.APIKey);
  OCMStub([self.mockAPIService projectID]).andReturn(self.projectID);
}

#pragma mark - Get Installation

- (void)testGetInstallationItem_WhenFIDExists_ThenItIsReturned {
  FIRInstallationsItem *storedInstallations =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallations]);

  // Don't expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];
  notificationExpectation.inverted = YES;

  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertEqual(promise.value, storedInstallations);

  OCMVerifyAll(self.mockInstallationsStore);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];
}

- (void)testGetInstallationItem_WhenNoFIDAndNoIID_ThenFIDIsCreatedAndRegistered {
  // 1. Stub store get installation.
  [self expectInstallationsStoreGetInstallationNotFound];

  // 2. Stub store save installation.
  __block FIRInstallationsItem *createdInstallation;

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  [self assertValidCreatedInstallation:obj];

                  createdInstallation = obj;
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 3. Stub API register installation.
  // 3.1. Verify installation to be registered.
  id registerInstallationValidation = [OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
    [self assertValidCreatedInstallation:obj];
    XCTAssertEqual(obj.firebaseInstallationID.length, 22);
    return YES;
  }];

  // 3.2. Expect for `registerInstallation` to be called.
  FBLPromise<FIRInstallationsItem *> *registerPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService registerInstallation:registerInstallationValidation])
      .andReturn(registerPromise);

  // 4. Expect IIDStore to be checked for existing IID.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:[FIRInstallationsErrorUtil keychainErrorWithFunction:@"" status:-1]];
  OCMExpect([self.mockIIDStore existingIID]).andReturn(rejectedPromise);

  // 5. Call get installation and check.
  FBLPromise<FIRInstallationsItem *> *getInstallationPromise =
      [self.controller getInstallationItem];

  // 5.1. Wait for the stored item to be read and saved.
  OCMVerifyAllWithDelay(self.mockInstallationsStore, 0.5);

  // 5.2. Wait for `registerInstallation` to be called.
  OCMVerifyAllWithDelay(self.mockAPIService, 0.5);

  // 5.3. Expect for the registered installation to be saved.
  FIRInstallationsItem *registeredInstallation = [FIRInstallationsItem
      createRegisteredInstallationItemWithAppID:createdInstallation.appID
                                        appName:createdInstallation.firebaseAppName];

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  XCTAssertEqual(registeredInstallation, obj);
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 5.5. Resolve `registerPromise` to simulate finished registration.
  [registerPromise fulfill:registeredInstallation];

  // 5.4. Wait for the task to complete.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(getInstallationPromise.error);
  // We expect the initially created installation to be returned - must not wait for registration to
  // complete here.
  XCTAssertEqual(getInstallationPromise.value, createdInstallation);

  // 5.5. Verify registered installation was saved.
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testGetInstallationItem_WhenThereIsIIDAndNoFID_ThenFIDIsCreatedAndRegistered {
  // 0. Configure controller with not default app.
  NSString *appName = @"appName";
  [self setUpWithAppName:appName];

  // 1. Stub store get installation.
  [self expectInstallationsStoreGetInstallationNotFound];

  // 2. Don't expect IIDStore to be checked for existing IID (not default app).
  OCMReject([self.mockIIDStore existingIID]);

  // 3. Stub store save installation.
  __block FIRInstallationsItem *createdInstallation;

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  [self assertValidCreatedInstallation:obj];

                  createdInstallation = obj;
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 4. Stub API register installation.
  // 4.1. Verify installation to be registered.
  id registerInstallationValidation = [OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
    [self assertValidCreatedInstallation:obj];
    return YES;
  }];

  // 4.2. Expect for `registerInstallation` to be called.
  FBLPromise<FIRInstallationsItem *> *registerPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService registerInstallation:registerInstallationValidation])
      .andReturn(registerPromise);

  // 5. Call get installation and check.
  FBLPromise<FIRInstallationsItem *> *getInstallationPromise =
      [self.controller getInstallationItem];

  // 5.1. Wait for the stored item to be read and saved.
  OCMVerifyAllWithDelay(self.mockInstallationsStore, 0.5);

  // 5.2. Wait for `registerInstallation` to be called.
  OCMVerifyAllWithDelay(self.mockAPIService, 0.5);

  // 5.3. Expect for the registered installation to be saved.
  FIRInstallationsItem *registeredInstallation = [FIRInstallationsItem
      createRegisteredInstallationItemWithAppID:createdInstallation.appID
                                        appName:createdInstallation.firebaseAppName];

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  XCTAssertEqual(registeredInstallation, obj);
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 5.5. Resolve `registerPromise` to simulate finished registration.
  [registerPromise fulfill:registeredInstallation];

  // 5.4. Wait for the task to complete.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(getInstallationPromise.error);
  // We expect the initially created installation to be returned - must not wait for registration to
  // complete here.
  XCTAssertEqual(getInstallationPromise.value, createdInstallation);

  // 5.5. Verify registered installation was saved.
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testGetInstallationItem_WhenThereIsIIDAndNoFIDNotDefaultApp_ThenIIDIsUsedAsFID {
  // 1. Stub store get installation.
  [self expectInstallationsStoreGetInstallationNotFound];

  // 2. Expect IIDStore to be checked for existing IID.
  NSString *existingIID = @"existing-iid";
  OCMExpect([self.mockIIDStore existingIID]).andReturn([FBLPromise resolvedWith:existingIID]);

  // 3. Stub store save installation.
  __block FIRInstallationsItem *createdInstallation;

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  [self assertValidCreatedInstallation:obj];
                  XCTAssertEqualObjects(existingIID, obj.firebaseInstallationID);
                  createdInstallation = obj;
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 4. Stub API register installation.
  // 4.1. Verify installation to be registered.
  id registerInstallationValidation = [OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
    [self assertValidCreatedInstallation:obj];
    XCTAssertEqualObjects(existingIID, obj.firebaseInstallationID);
    return YES;
  }];

  // 4.2. Expect for `registerInstallation` to be called.
  FBLPromise<FIRInstallationsItem *> *registerPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService registerInstallation:registerInstallationValidation])
      .andReturn(registerPromise);

  // 5. Call get installation and check.
  FBLPromise<FIRInstallationsItem *> *getInstallationPromise =
      [self.controller getInstallationItem];

  // 5.1. Wait for the stored item to be read and saved.
  OCMVerifyAllWithDelay(self.mockInstallationsStore, 0.5);

  // 5.2. Wait for `registerInstallation` to be called.
  OCMVerifyAllWithDelay(self.mockAPIService, 0.5);

  // 5.3. Expect for the registered installation to be saved.
  FIRInstallationsItem *registeredInstallation = [FIRInstallationsItem
      createRegisteredInstallationItemWithAppID:createdInstallation.appID
                                        appName:createdInstallation.firebaseAppName];

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  XCTAssertEqual(registeredInstallation, obj);
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 5.5. Resolve `registerPromise` to simulate finished registration.
  [registerPromise fulfill:registeredInstallation];

  // 5.4. Wait for the task to complete.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(getInstallationPromise.error);
  // We expect the initially created installation to be returned - must not wait for registration to
  // complete here.
  XCTAssertEqual(getInstallationPromise.value, createdInstallation);

  // 5.5. Verify registered installation was saved.
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testGetInstallationItem_WhenCalledSeveralTimes_OnlyOneOperationIsPerformed {
  // 1. Expect the installation to be requested from the store only once.
  FIRInstallationsItem *storedInstallation1 =
      [FIRInstallationsItem createRegisteredInstallationItem];
  FBLPromise<FIRInstallationsItem *> *pendingStorePromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn(pendingStorePromise);

  // 3. Request installation n times
  NSInteger requestCount = 10;
  NSMutableArray *installationPromises = [NSMutableArray arrayWithCapacity:requestCount];
  for (NSInteger i = 0; i < requestCount; i++) {
    [installationPromises addObject:[self.controller getInstallationItem]];
  }

  // 4. Resolve store promise.
  [pendingStorePromise fulfill:storedInstallation1];

  // 5. Wait for operation to be completed and check.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  for (FBLPromise<FIRInstallationsItem *> *installationPromise in installationPromises) {
    XCTAssertNil(installationPromise.error);
    XCTAssertEqual(installationPromise.value, storedInstallation1);
  }

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);

  // 6. Check that a new request is performed once previous finished.
  FIRInstallationsItem *storedInstallation2 =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation2]);

  FBLPromise<FIRInstallationsItem *> *installationPromise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(installationPromise.error);
  XCTAssertEqual(installationPromise.value, storedInstallation2);

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

#pragma mark - Get Auth Token

- (void)testGetAuthToken_WhenValidInstallationExists_ThenItIsReturned {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 2. Request auth token.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getAuthTokenForcingRefresh:NO];

  // 3. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 4. Check.
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertEqualObjects(promise.value.authToken.token, storedInstallation.authToken.token);
  XCTAssertEqualObjects(promise.value.authToken.expirationDate,
                        storedInstallation.authToken.expirationDate);
}

- (void)testGetAuthToken_WhenValidInstallationWithExpiredTokenExists_ThenTokenRequested {
  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  storedInstallation.authToken.expirationDate = [NSDate dateWithTimeIntervalSinceNow:60 * 60 - 1];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Expect API request.
  FIRInstallationsItem *responseInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  responseInstallation.authToken.token =
      [responseInstallation.authToken.token stringByAppendingString:@"_new"];
  OCMExpect([self.mockAPIService refreshAuthTokenForInstallation:storedInstallation])
      .andReturn([FBLPromise resolvedWith:responseInstallation]);

  // 2. Request auth token.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getAuthTokenForcingRefresh:NO];

  // 3. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 4. Check.
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertEqualObjects(promise.value.authToken.token, responseInstallation.authToken.token);
  XCTAssertEqualObjects(promise.value.authToken.expirationDate,
                        responseInstallation.authToken.expirationDate);
}

- (void)testGetAuthTokenForcingRefresh_WhenValidInstallationExists_ThenTokenRequested {
  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Expect API request.
  FIRInstallationsItem *responseInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  responseInstallation.authToken.token =
      [responseInstallation.authToken.token stringByAppendingString:@"_new"];
  OCMExpect([self.mockAPIService refreshAuthTokenForInstallation:storedInstallation])
      .andReturn([FBLPromise resolvedWith:responseInstallation]);

  // 2. Request auth token.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getAuthTokenForcingRefresh:YES];

  // 3. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 4. Check.
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertEqualObjects(promise.value.authToken.token, responseInstallation.authToken.token);
  XCTAssertEqualObjects(promise.value.authToken.expirationDate,
                        responseInstallation.authToken.expirationDate);
}

- (void)testGetAuthToken_WhenCalledSeveralTimes_OnlyOneOperationIsPerformed {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];

  FBLPromise *storagePendingPromise = [FBLPromise pendingPromise];
  // Expect the installation to be requested only once.
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn(storagePendingPromise);

  // 2. Request auth token n times.
  NSInteger requestCount = 10;
  NSMutableArray *authTokenPromises = [NSMutableArray arrayWithCapacity:requestCount];
  for (NSInteger i = 0; i < requestCount; i++) {
    [authTokenPromises addObject:[self.controller getAuthTokenForcingRefresh:NO]];
  }

  // 3. Finish the storage request.
  [storagePendingPromise fulfill:storedInstallation];

  // 4. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 5. Check.
  OCMVerifyAll(self.mockInstallationsStore);

  for (FBLPromise<FIRInstallationsItem *> *authPromise in authTokenPromises) {
    XCTAssertNil(authPromise.error);
    XCTAssertNotNil(authPromise.value);

    XCTAssertEqualObjects(authPromise.value.authToken.token, storedInstallation.authToken.token);
    XCTAssertEqualObjects(authPromise.value.authToken.expirationDate,
                          storedInstallation.authToken.expirationDate);
  }
}

- (void)testGetAuthTokenForceRefresh_WhenCalledSeveralTimes_OnlyOneOperationIsPerformed {
  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Expect API request.
  FIRInstallationsItem *responseInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  responseInstallation.authToken.token =
      [responseInstallation.authToken.token stringByAppendingString:@"_new"];
  FBLPromise *pendingAPIPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService refreshAuthTokenForInstallation:storedInstallation])
      .andReturn(pendingAPIPromise);

  // 2. Request auth token n times.
  NSInteger requestCount = 10;
  NSMutableArray *authTokenPromises = [NSMutableArray arrayWithCapacity:requestCount];
  for (NSInteger i = 0; i < requestCount; i++) {
    [authTokenPromises addObject:[self.controller getAuthTokenForcingRefresh:YES]];
  }

  // 3. Finish the API request.
  [pendingAPIPromise fulfill:responseInstallation];

  // 4. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 5. Check.
  OCMVerifyAll(self.mockInstallationsStore);

  for (FBLPromise<FIRInstallationsItem *> *authPromise in authTokenPromises) {
    XCTAssertNil(authPromise.error);
    XCTAssertNotNil(authPromise.value);

    XCTAssertEqualObjects(authPromise.value.authToken.token, responseInstallation.authToken.token);
    XCTAssertEqualObjects(authPromise.value.authToken.expirationDate,
                          responseInstallation.authToken.expirationDate);
  }
}

#pragma mark - FID Deletion

- (void)testDeleteRegisteredInstallation {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:installation.appID
                                                      appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:installation]);

  // 2. Expect API request to delete installation.
  OCMExpect([self.mockAPIService deleteInstallation:installation])
      .andReturn([FBLPromise resolvedWith:installation]);

  // 3.1. Expect the installation to be removed from the storage.
  OCMExpect([self.mockInstallationsStore removeInstallationForAppID:installation.appID
                                                            appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 3.2. Expect IID to be deleted, because it is default app.
  OCMExpect([self.mockIIDStore deleteExistingIID])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 4. Expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];

  // 5. Call delete installation.
  FBLPromise<NSNull *> *promise = [self.controller deleteInstallation];

  // 6. Wait for operations to complete and check.
  FBLWaitForPromisesWithTimeout(0.5);

  XCTAssertNil(promise.error);
  XCTAssertTrue(promise.isFulfilled);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testDeleteUnregisteredInstallation {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *installation = [FIRInstallationsItem createUnregisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:installation.appID
                                                      appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:installation]);

  // 2. Don't expect API request to delete installation.
  OCMReject([self.mockAPIService deleteInstallation:[OCMArg any]]);

  // 3.1. Expect the installation to be removed from the storage.
  OCMExpect([self.mockInstallationsStore removeInstallationForAppID:installation.appID
                                                            appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 3.2. Expect IID to be deleted, because it is default app.
  OCMExpect([self.mockIIDStore deleteExistingIID])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 4. Expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];

  // 5. Call delete installation.
  FBLPromise<NSNull *> *promise = [self.controller deleteInstallation];

  // 6. Wait for operations to complete and check.
  FBLWaitForPromisesWithTimeout(0.5);

  XCTAssertNil(promise.error);
  XCTAssertTrue(promise.isFulfilled);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testDeleteRegisteredInstallation_WhenAPIRequestFails_ThenFailsAndInstallationIsNotRemoved {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:installation.appID
                                                      appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:installation]);

  // 2. Expect API request to delete installation.
  FBLPromise *rejectedAPIPromise = [FBLPromise pendingPromise];
  NSError *error500 =
      [FIRInstallationsErrorUtil APIErrorWithHTTPCode:kFIRInstallationsAPIInternalErrorHTTPCode];
  [rejectedAPIPromise reject:error500];
  OCMExpect([self.mockAPIService deleteInstallation:installation]).andReturn(rejectedAPIPromise);

  // 3.1. Don't expect the installation to be removed from the storage.
  OCMReject([self.mockInstallationsStore removeInstallationForAppID:[OCMArg any]
                                                            appName:[OCMArg any]]);
  // 3.2. Don't expect IID to be deleted.
  OCMReject([self.mockIIDStore deleteExistingIID]);

  // 4. Don't expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];
  notificationExpectation.inverted = YES;

  // 5. Call delete installation.
  FBLPromise<NSNull *> *promise = [self.controller deleteInstallation];

  // 6. Wait for operations to complete and check.
  FBLWaitForPromisesWithTimeout(0.5);

  XCTAssertEqualObjects(promise.error, error500);
  XCTAssertTrue(promise.isRejected);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testDeleteRegisteredInstallation_WhenAPIFailsWithNotFound_ThenInstallationIsRemoved {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *installation = [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:installation.appID
                                                      appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:installation]);

  // 2. Expect API request to delete installation.
  FBLPromise *rejectedAPIPromise = [FBLPromise pendingPromise];
  [rejectedAPIPromise reject:[FIRInstallationsErrorUtil APIErrorWithHTTPCode:404]];
  OCMExpect([self.mockAPIService deleteInstallation:installation]).andReturn(rejectedAPIPromise);

  // 3. Expect the installation to be removed from the storage.
  OCMExpect([self.mockInstallationsStore removeInstallationForAppID:installation.appID
                                                            appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);
  // 3.2. Expect IID to be deleted, because it is default app.
  OCMExpect([self.mockIIDStore deleteExistingIID])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 4. Expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];

  // 5. Call delete installation.
  FBLPromise<NSNull *> *promise = [self.controller deleteInstallation];

  // 6. Wait for operations to complete and check.
  FBLWaitForPromisesWithTimeout(0.5);

  XCTAssertNil(promise.error);
  XCTAssertTrue(promise.isFulfilled);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testDeleteInstallation_WhenThereIsOngoingAuthTokenRequest_ThenUsesItsResult {
  // 1. Stub mocks for auth token request.

  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Expect API request.
  FIRInstallationsItem *responseInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  responseInstallation.authToken.token =
      [responseInstallation.authToken.token stringByAppendingString:@"_new"];
  FBLPromise *pendingAuthTokenAPIPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService refreshAuthTokenForInstallation:storedInstallation])
      .andReturn(pendingAuthTokenAPIPromise);

  // 2. Send auth token request.
  [self.controller getAuthTokenForcingRefresh:YES];

  OCMVerifyAllWithDelay(self.mockInstallationsStore, 0.5);
  OCMVerifyAllWithDelay(self.mockAPIService, 0.5);

  // 3. Delete installation.

  // 3.1. Don't expect installation to be requested from the store.
  OCMReject([self.mockInstallationsStore installationForAppID:[OCMArg any] appName:[OCMArg any]]);

  // 3.2. Expect API request to delete the UPDATED installation.
  OCMExpect([self.mockAPIService deleteInstallation:responseInstallation])
      .andReturn([FBLPromise resolvedWith:responseInstallation]);

  // 3.3. Expect the UPDATED installation to be removed from the storage.
  OCMExpect([self.mockInstallationsStore
                removeInstallationForAppID:responseInstallation.appID
                                   appName:responseInstallation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 3.4. Expect IID to be deleted, because it is default app.
  OCMExpect([self.mockIIDStore deleteExistingIID])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 3.4. Call delete installation.
  FBLPromise<NSNull *> *deletePromise = [self.controller deleteInstallation];

  // 4. Fulfill auth token promise to proceed.
  [pendingAuthTokenAPIPromise fulfill:responseInstallation];

  // 5. Wait for operations to complete and check the result.
  FBLWaitForPromisesWithTimeout(0.5);

  XCTAssertNil(deletePromise.error);
  XCTAssertTrue(deletePromise.isFulfilled);

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockIIDStore);
}

- (void)testDeleteInstallation_WhenNotDefaultApp_ThenIIDIsNotDeleted {
  // 0. Configure controller for not default app.
  NSString *appName = @"appName";
  [self setUpWithAppName:appName];

  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *installation =
      [FIRInstallationsItem createRegisteredInstallationItemWithAppID:self.appID appName:appName];
  OCMExpect([self.mockInstallationsStore installationForAppID:installation.appID
                                                      appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:installation]);

  // 2. Expect API request to delete installation.
  OCMExpect([self.mockAPIService deleteInstallation:installation])
      .andReturn([FBLPromise resolvedWith:installation]);

  // 3.1. Expect the installation to be removed from the storage.
  OCMExpect([self.mockInstallationsStore removeInstallationForAppID:installation.appID
                                                            appName:installation.firebaseAppName])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 3.2. Don't expect IID to be deleted, because it is not a default app.
  OCMReject([self.mockIIDStore deleteExistingIID]);

  // 4. Expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];

  // 5. Call delete installation.
  FBLPromise<NSNull *> *promise = [self.controller deleteInstallation];

  // 6. Wait for operations to complete and check.
  FBLWaitForPromisesWithTimeout(0.5);

  XCTAssertNil(promise.error);
  XCTAssertTrue(promise.isFulfilled);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockIIDStore);
}

// TODO: Test a single delete installation request at a time.

#pragma mark - Notifications

- (void)testFIDDidChangeNotificationIsSentWhenFIDCreated {
  // 1. Stub - no installation.
  // 1.2. FID store.
  [self expectInstallationsStoreGetInstallationNotFound];

  OCMStub([self.mockInstallationsStore saveInstallation:[OCMArg any]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 1.3. IID store.
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:[FIRInstallationsErrorUtil keychainErrorWithFunction:@"" status:-1]];
  OCMExpect([self.mockIIDStore existingIID]).andReturn(rejectedPromise);

  // 1.4. API Service.
  OCMExpect([self.mockAPIService registerInstallation:[OCMArg any]])
      .andReturn([FBLPromise resolvedWith:[FIRInstallationsItem createRegisteredInstallationItem]]);

  // 2. Expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];

  // 3. Request FID.
  FBLPromise *promise = [self.controller getInstallationItem];
  FBLWaitForPromisesWithTimeout(0.5);

  // 4. Check.
  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockIIDStore);
  OCMVerifyAll(self.mockAPIService);
}

- (void)testRegisterInstallation_WhenServerRespondsWithDifferentFID_ThenFIDDidChangeNotification {
  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createUnregisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Expect register FID to be called.
  FIRInstallationsItem *receivedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  receivedInstallation.firebaseInstallationID =
      [storedInstallation.firebaseInstallationID stringByAppendingString:@"_new"];
  OCMExpect([self.mockAPIService registerInstallation:storedInstallation])
      .andReturn([FBLPromise resolvedWith:receivedInstallation]);

  // 1.3. Expect the received installation to be stored.
  OCMExpect([self.mockInstallationsStore saveInstallation:receivedInstallation])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 2. Expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];

  // 3. Request Auth Token.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getAuthTokenForcingRefresh:NO];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 4. Check.
  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);
  XCTAssertEqualObjects(promise.value.firebaseInstallationID,
                        receivedInstallation.firebaseInstallationID);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

#pragma mark - Registration Failures

- (void)testRegisterInstallation_WhenServerRespondsWith429_ThenErrorIsNotStoredAndReturned {
  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createUnregisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Receive HTTP 429.
  NSError *APIError = [FIRInstallationsErrorUtil APIErrorWithHTTPCode:429];
  FBLPromise *rejectedAPIPromise = [FBLPromise pendingPromise];
  [rejectedAPIPromise reject:APIError];
  OCMExpect([self.mockAPIService registerInstallation:storedInstallation])
      .andReturn(rejectedAPIPromise);

  // 1.3. Don't expect the installation to be stored with the error.
  OCMReject([self.mockInstallationsStore saveInstallation:[OCMArg any]]);

  // 2. Request Installation.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 4. Check.
  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  // The unregistered installation should be returned before the registration attempt.
  XCTAssertEqual(promise.value.registrationStatus, FIRInstallationStatusUnregistered);

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

- (void)testRegisterInstallation_WhenServerRespondsWith400_ThenErrorStoredAndReturned {
  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createUnregisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Receive HTTP 400.
  NSError *APIError = [FIRInstallationsErrorUtil APIErrorWithHTTPCode:400];
  FBLPromise *rejectedAPIPromise = [FBLPromise pendingPromise];
  [rejectedAPIPromise reject:APIError];
  OCMExpect([self.mockAPIService registerInstallation:storedInstallation])
      .andReturn(rejectedAPIPromise);

  // 1.3. Expect the installation to be stored with the error.
  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *installation) {
                  XCTAssertEqual(installation.registrationStatus,
                                 FIRInstallationStatusRegistrationFailed);
                  XCTAssertEqualObjects(installation.registrationError.APIError, APIError);
                  XCTAssertEqualObjects(
                      installation.registrationError.registrationParameters.APIKey, self.APIKey);
                  XCTAssertEqualObjects(
                      installation.registrationError.registrationParameters.projectID,
                      self.projectID);
                  XCTAssertNotNil(installation.registrationError.date);
                  [self assertDate:installation.registrationError.date
                      isApproximatelyEqualCurrentPlusTimeInterval:0];
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 2. Request Installation.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 4. Check.
  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  // The unregistered installation should be returned before the registration attempt.
  XCTAssertEqual(promise.value.registrationStatus, FIRInstallationStatusUnregistered);

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetInstallation_WhenRegistrationErrorStoredAndConfigurationIsTheSame_ThenFails {
  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [self createFailedToRegisterInstallationWithParameters:[self currentRegistrationParameters]];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 1.2. Don't expect registration API request to be sent.
  OCMReject([self.mockAPIService registerInstallation:[OCMArg any]]);

  // 2. Request Installation.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 3. Check.
  XCTAssertFalse(promise.isFulfilled);
  XCTAssertEqualObjects(promise.error, storedInstallation.registrationError.APIError);

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

- (void)
    testGetInstallation_WhenRegistrationErrorStoredAndConfigurationDifferent_ThenSendsAPIRequest {
  __block FBLPromise<FIRInstallationsItem *> *storedInstallationPromise;
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andDo(^(NSInvocation *invocation) {
        [invocation setReturnValue:&storedInstallationPromise];
      });

  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [self createFailedToRegisterInstallationWithParameters:[self otherRegistrationParameters]];
  storedInstallationPromise = [FBLPromise resolvedWith:storedInstallation];

  // 1.2. Expect registration API request to be sent.
  FIRInstallationsItem *registeredInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockAPIService registerInstallation:storedInstallation])
      .andReturn([FBLPromise resolvedWith:registeredInstallation]);

  // 1.3. Expect registered Installation to be stored.
  OCMExpect([self.mockInstallationsStore saveInstallation:[OCMArg checkWithBlock:^BOOL(id obj) {
                                           XCTAssertEqualObjects(obj, registeredInstallation);
                                           storedInstallationPromise =
                                               [FBLPromise resolvedWith:obj];
                                           return YES;
                                         }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 2. Request Installation.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 3. Check.
  XCTAssertEqualObjects(promise.value.identifier, registeredInstallation.identifier);
  XCTAssertNil(promise.error);

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetInstallation_WhenStoredRegistrationErrorIsOutdated_ThenSendsAPIRequest {
  __block FBLPromise<FIRInstallationsItem *> *storedInstallationPromise;
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andDo(^(NSInvocation *invocation) {
        [invocation setReturnValue:&storedInstallationPromise];
      });

  // 1.1. Expect installation to be requested from the store.
  NSDate *date25HoursAgo = [NSDate dateWithTimeIntervalSinceNow:-25 * 60 * 60];
  FIRInstallationsItem *storedInstallation =
      [self createFailedToRegisterInstallationWithParameters:[self currentRegistrationParameters]
                                                        date:date25HoursAgo];
  storedInstallationPromise = [FBLPromise resolvedWith:storedInstallation];

  // 1.2. Expect registration API request to be sent.
  FIRInstallationsItem *registeredInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockAPIService registerInstallation:storedInstallation])
      .andReturn([FBLPromise resolvedWith:registeredInstallation]);

  // 1.3. Expect registered Installation to be stored.
  OCMExpect([self.mockInstallationsStore saveInstallation:[OCMArg checkWithBlock:^BOOL(id obj) {
                                           XCTAssertEqualObjects(obj, registeredInstallation);
                                           storedInstallationPromise =
                                               [FBLPromise resolvedWith:obj];
                                           return YES;
                                         }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 2. Request Installation.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  // 3. Check.
  XCTAssertEqualObjects(promise.value.identifier, registeredInstallation.identifier);
  XCTAssertNil(promise.error);

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

#pragma mark - Helpers

- (void)expectInstallationsStoreGetInstallationNotFound {
  NSError *notFoundError =
      [FIRInstallationsErrorUtil installationItemNotFoundForAppID:self.appID appName:self.appName];
  FBLPromise *installationNotFoundPromise = [FBLPromise pendingPromise];
  [installationNotFoundPromise reject:notFoundError];

  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn(installationNotFoundPromise);
}

- (void)assertValidCreatedInstallation:(FIRInstallationsItem *)installation {
  XCTAssertEqualObjects([installation class], [FIRInstallationsItem class]);
  XCTAssertEqualObjects(installation.appID, self.appID);
  XCTAssertEqualObjects(installation.firebaseAppName, self.appName);
  XCTAssertEqual(installation.registrationStatus, FIRInstallationStatusUnregistered);
  XCTAssertNotNil(installation.firebaseInstallationID);
}

- (XCTestExpectation *)installationIDDidChangeNotificationExpectation {
  XCTestExpectation *notificationExpectation = [self
      expectationForNotification:FIRInstallationIDDidChangeNotification
                          object:nil
                         handler:^BOOL(NSNotification *_Nonnull notification) {
                           XCTAssertEqualObjects(
                               notification
                                   .userInfo[kFIRInstallationIDDidChangeNotificationAppNameKey],
                               self.appName);
                           return YES;
                         }];
  return notificationExpectation;
}

- (FIRInstallationsItem *)createFailedToRegisterInstallationWithParameters:
                              (FIRInstallationsStoredRegistrationParameters *)registrationParameters
                                                                      date:(NSDate *)date {
  FIRInstallationsStoredRegistrationError *error = [[FIRInstallationsStoredRegistrationError alloc]
      initWithRegistrationParameters:registrationParameters
                                date:date
                            APIError:[FIRInstallationsErrorUtil APIErrorWithHTTPCode:400]];
  FIRInstallationsItem *installation = [FIRInstallationsItem createWithRegistrationFailure:error];
  return installation;
}

- (FIRInstallationsItem *)createFailedToRegisterInstallationWithParameters:
    (FIRInstallationsStoredRegistrationParameters *)registrationParameters {
  return [self createFailedToRegisterInstallationWithParameters:registrationParameters
                                                           date:[NSDate date]];
}

- (FIRInstallationsStoredRegistrationParameters *)currentRegistrationParameters {
  return [[FIRInstallationsStoredRegistrationParameters alloc] initWithAPIKey:self.APIKey
                                                                    projectID:self.projectID];
}

- (FIRInstallationsStoredRegistrationParameters *)otherRegistrationParameters {
  NSString *APIKey = [@"another" stringByAppendingString:self.APIKey];
  NSString *projectID = [@"another" stringByAppendingString:self.projectID];
  return [[FIRInstallationsStoredRegistrationParameters alloc] initWithAPIKey:APIKey
                                                                    projectID:projectID];
}

@end
