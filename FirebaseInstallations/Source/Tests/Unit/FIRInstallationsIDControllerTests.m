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
#import "FBLPromise+Then.h"
#import "FIRInstallationsErrorUtil+Tests.h"
#import "FIRInstallationsItem+Tests.h"

#import "FIRInstallations.h"
#import "FIRInstallationsAPIService.h"
#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsHTTPError.h"
#import "FIRInstallationsIDController.h"
#import "FIRInstallationsIIDStore.h"
#import "FIRInstallationsIIDTokenStore.h"
#import "FIRInstallationsStore.h"

#import "FIRInstallationsStoredAuthToken.h"

@interface FIRInstallationsIDController (Tests)
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                 installationsStore:(FIRInstallationsStore *)installationsStore
                         APIService:(FIRInstallationsAPIService *)APIService
                           IIDStore:(FIRInstallationsIIDStore *)IIDStore
                      IIDTokenStore:(FIRInstallationsIIDTokenStore *)IIDTokenStore;
@end

@interface FIRInstallationsIDControllerTests : XCTestCase
@property(nonatomic) FIRInstallationsIDController *controller;
@property(nonatomic) id mockInstallationsStore;
@property(nonatomic) id mockAPIService;
@property(nonatomic) id mockIIDStore;
@property(nonatomic) id mockIIDTokenStore;
@property(nonatomic) NSString *appID;
@property(nonatomic) NSString *appName;
@end

@implementation FIRInstallationsIDControllerTests

- (void)setUp {
  [self setUpWithAppName:kFIRDefaultAppName];
}

- (void)setUpWithAppName:(NSString *)appName {
  self.appID = @"appID";
  self.appName = appName;
  self.mockInstallationsStore = OCMStrictClassMock([FIRInstallationsStore class]);
  self.mockAPIService = OCMStrictClassMock([FIRInstallationsAPIService class]);
  self.mockIIDStore = OCMStrictClassMock([FIRInstallationsIIDStore class]);
  self.mockIIDTokenStore = OCMStrictClassMock([FIRInstallationsIIDTokenStore class]);

  self.controller =
      [[FIRInstallationsIDController alloc] initWithGoogleAppID:self.appID
                                                        appName:self.appName
                                             installationsStore:self.mockInstallationsStore
                                                     APIService:self.mockAPIService
                                                       IIDStore:self.mockIIDStore
                                                  IIDTokenStore:self.mockIIDTokenStore];
}

- (void)tearDown {
  self.controller = nil;
  self.mockIIDStore = nil;
  self.mockAPIService = nil;
  self.mockInstallationsStore = nil;
  self.appID = nil;
  self.appName = nil;
}

#pragma mark - Initialization

- (void)testInitWhenProjectIDSetThenItIsPassedToAPIService {
  NSString *APIKey = @"api-key";
  NSString *projectID = @"project-id";
  OCMExpect([self.mockAPIService alloc]).andReturn(self.mockAPIService);
  OCMExpect([self.mockAPIService initWithAPIKey:APIKey projectID:projectID])
      .andReturn(self.mockAPIService);

  FIRInstallationsIDController *controller =
      [[FIRInstallationsIDController alloc] initWithGoogleAppID:@"app-id"
                                                        appName:@"app-name"
                                                         APIKey:APIKey
                                                      projectID:projectID
                                                    GCMSenderID:@"sender-id"
                                                    accessGroup:nil];
  XCTAssertNotNil(controller);

  OCMVerifyAll(self.mockAPIService);
}

- (void)testInitWhenProjectIDIsNilThenGCMSenderIDIsPassedToAPIServiceAsProjectID {
  NSString *APIKey = @"api-key";
  NSString *GCMSenderID = @"sender-id";
  OCMExpect([self.mockAPIService alloc]).andReturn(self.mockAPIService);
  OCMExpect([self.mockAPIService initWithAPIKey:APIKey projectID:GCMSenderID])
      .andReturn(self.mockAPIService);

  FIRInstallationsIDController *controller =
      [[FIRInstallationsIDController alloc] initWithGoogleAppID:@"app-id"
                                                        appName:@"app-name"
                                                         APIKey:APIKey
                                                      projectID:@""
                                                    GCMSenderID:GCMSenderID
                                                    accessGroup:nil];
  XCTAssertNotNil(controller);

  OCMVerifyAll(self.mockAPIService);
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
  [self expectStoredIIDNotFound];

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

- (void)testGetInstallationItem_WhenThereIsIIDAndNoFID_ThenFIDIsCreatedAndRegistered {
  // 1. Stub store get installation.
  [self expectInstallationsStoreGetInstallationNotFound];

  // 2. Expect IIDStore to be checked for existing IID.
  NSString *existingIID = @"existing-iid";
  OCMExpect([self.mockIIDStore existingIID]).andReturn([FBLPromise resolvedWith:existingIID]);

  // 3. Expect IID checkin store to be requested for checkin data.
  NSString *existingIIDDefaultToken = @"existing-iid-token";
  OCMExpect([self.mockIIDTokenStore existingIIDDefaultToken])
      .andReturn([FBLPromise resolvedWith:existingIIDDefaultToken]);

  // 3. Stub store save installation.
  __block FIRInstallationsItem *createdInstallation;

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  [self assertValidCreatedInstallation:obj];
                  XCTAssertEqualObjects(existingIID, obj.firebaseInstallationID);
                  XCTAssertEqualObjects(obj.IIDDefaultToken, existingIIDDefaultToken);
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
  OCMVerifyAll(self.mockIIDTokenStore);
}

- (void)testGetInstallationItem_WhenCalledWhileRegistering_DoesNotWaitForAPIResponse {
  // 1. Expect the installation to be requested from the store only once.
  FIRInstallationsItem *storedInstallation1 =
      [FIRInstallationsItem createUnregisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation1]);

  // 2. Expect registration API request to be sent.
  FBLPromise<FIRInstallationsItem *> *pendingAPIPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService registerInstallation:storedInstallation1])
      .andReturn(pendingAPIPromise);

  // 3. Request and wait for 1st FID.
  FBLPromise<FIRInstallationsItem *> *getInstallationPromise1 =
      [self.controller getInstallationItem];
  XCTestExpectation *getInstallationsExpectation1 =
      [self expectationWithDescription:@"getInstallationsExpectation1"];
  getInstallationPromise1.then(^id(FIRInstallationsItem *installation) {
    [getInstallationsExpectation1 fulfill];
    return nil;
  });
  [self waitForExpectations:@[ getInstallationsExpectation1 ] timeout:0.5];

  // 4. Request FID 2nd time.
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation1]);

  FBLPromise<FIRInstallationsItem *> *getInstallationPromise2 =
      [self.controller getInstallationItem];
  XCTestExpectation *getInstallationsExpectation2 =
      [self expectationWithDescription:@"getInstallationsExpectation2"];
  getInstallationPromise2.then(^id(FIRInstallationsItem *installation) {
    [getInstallationsExpectation2 fulfill];
    return nil;
  });
  [self waitForExpectations:@[ getInstallationsExpectation2 ] timeout:0.5];

  // 5. Resolve API promise.
  [pendingAPIPromise reject:[FIRInstallationsErrorUtil APIErrorWithHTTPCode:400]];

  // 6. Check
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
}

- (void)testGetInstallationItem_WhenCalledSeveralTimesWaitingForStore_OnlyOneOperationIsPerformed {
  // 1. Expect the installation to be requested from the store only once.
  FIRInstallationsItem *storedInstallation1 =
      [FIRInstallationsItem createRegisteredInstallationItem];
  FBLPromise<FIRInstallationsItem *> *pendingStorePromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn(pendingStorePromise);

  // 2. Request installation n times
  NSInteger requestCount = 10;
  NSMutableArray *installationPromises = [NSMutableArray arrayWithCapacity:requestCount];
  for (NSInteger i = 0; i < requestCount; i++) {
    [installationPromises addObject:[self.controller getInstallationItem]];
  }

  // 3. Resolve store promise.
  [pendingStorePromise fulfill:storedInstallation1];

  // 4. Wait for operation to be completed and check.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  for (FBLPromise<FIRInstallationsItem *> *installationPromise in installationPromises) {
    XCTAssertNil(installationPromise.error);
    XCTAssertEqual(installationPromise.value, storedInstallation1);
  }

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);

  // 5. Check that a new request is performed once previous finished.
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

- (void)testGetInstallationItem_WhenCalledSeveralTimesWaitingForAPI_OnlyOneAPIRequestIsSent {
  // 1. Expect a single API request.
  FBLPromise<FIRInstallationsItem *> *registerAPIPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService registerInstallation:[OCMArg any]]).andReturn(registerAPIPromise);

  // 2. Request FID multiple times.
  NSInteger requestCount = 10;
  for (NSInteger i = 0; i < requestCount; i++) {
    XCTestExpectation *getFIDExpectation = [self
        expectationWithDescription:[NSString stringWithFormat:@"getFIDExpectation%ld", (long)i]];

    // 2.1. Expect stored FID to be requested.
    FIRInstallationsItem *storedInstallation =
        [FIRInstallationsItem createUnregisteredInstallationItem];
    OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
        .andReturn([FBLPromise resolvedWith:storedInstallation]);

    // 2.2. Expect the FID to be returned.
    FBLPromise<FIRInstallationsItem *> *getFIDPromise = [self.controller getInstallationItem];

    [getFIDPromise then:^id _Nullable(FIRInstallationsItem *_Nullable value) {
      XCTAssertNotNil(value);
      XCTAssertEqualObjects(value.firebaseInstallationID,
                            storedInstallation.firebaseInstallationID);
      [getFIDExpectation fulfill];
      return nil;
    }];

    [self waitForExpectations:@[ getFIDExpectation ] timeout:0.5];
  }

  // 3. Finish API request.
  [registerAPIPromise reject:[FIRInstallationsErrorUtil APIErrorWithHTTPCode:400]];

  // 4. Verify mocks
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
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
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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

  // 1.2. Auth Token refresh.
  FIRInstallationsItem *responseInstallation =
      [self expectAuthTokenRefreshForInstallation:storedInstallation];

  // 2. Request auth token.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getAuthTokenForcingRefresh:NO];

  // 3. Wait for the promise to resolve.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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

  // 1.2. Auth Token refresh.
  FIRInstallationsItem *responseInstallation =
      [self expectAuthTokenRefreshForInstallation:storedInstallation];

  // 2. Request auth token.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getAuthTokenForcingRefresh:YES];

  // 3. Wait for the promise to resolve.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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

  // 1.3. Expect new token to be stored.
  OCMExpect([self.mockInstallationsStore saveInstallation:responseInstallation])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 2. Request auth token n times.
  NSInteger requestCount = 10;
  NSMutableArray *authTokenPromises = [NSMutableArray arrayWithCapacity:requestCount];
  for (NSInteger i = 0; i < requestCount; i++) {
    [authTokenPromises addObject:[self.controller getAuthTokenForcingRefresh:YES]];
  }

  // 3. Finish the API request.
  [pendingAPIPromise fulfill:responseInstallation];

  // 4. Wait for the promise to resolve.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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

- (void)testGetAuthToken_WhenAPIResponse401_ThenFISResetAndReregistered {
  NSTimeInterval timeout = 0.5;

  // 1.1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  [self expectInstallationStoreToBeRequestedAndReturnInstallation:storedInstallation];

  // 1.2. Expect API request.
  FBLPromise *rejectedAPIPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService refreshAuthTokenForInstallation:storedInstallation])
      .andReturn(rejectedAPIPromise);

  // 2. Request auth token.
  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getAuthTokenForcingRefresh:YES];

  // 3. Wait for refresh token request.
  OCMVerifyAllWithDelay(self.mockAPIService, timeout);

  // 4.1. Expect Installation to be requested before deletion.
  [self expectInstallationStoreToBeRequestedAndReturnInstallation:storedInstallation];
  // 4. Expect for FIS to be deleted locally.
  NSArray<XCTestExpectation *> *deleteExpectations =
      [self expectInstallationToBeDeletedLocally:storedInstallation];

  // 6. Expect a new installation to be created and registered.
  // 6.1. Expect to request FIS from storage.
  [self expectInstallationsStoreGetInstallationNotFound];
  // 6.2. Expect stored IID not found.
  [self expectStoredIIDNotFound];
  // 6.3. Expect new Installation to be stored.
  __block FIRInstallationsItem *createdInstallation;
  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  [self assertValidCreatedInstallation:obj];

                  createdInstallation = obj;
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);
  // 6.4. Expect registration API request to be sent.
  FBLPromise<FIRInstallationsItem *> *registerPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService registerInstallation:[OCMArg any]]).andReturn(registerPromise);

  // 6.5. Reject API request promise with 401.
  NSError *error401 = [FIRInstallationsErrorUtil APIErrorWithHTTPCode:404];
  [rejectedAPIPromise reject:error401];
  // 6.6. Wait local FIS to be deleted.
  [self waitForExpectations:deleteExpectations timeout:timeout];

  // 6.7 Wait for the new Installation to be stored.
  OCMVerifyAllWithDelay(self.mockInstallationsStore, timeout);
  // 6.8. Wait for registration API request to be sent.
  OCMVerifyAllWithDelay(self.mockAPIService, timeout);
  // 6.9.  Expect for the registered installation to be saved.
  FIRInstallationsItem *registeredInstallation = [FIRInstallationsItem
      createRegisteredInstallationItemWithAppID:createdInstallation.appID
                                        appName:createdInstallation.firebaseAppName];

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  XCTAssertEqual(registeredInstallation, obj);
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);
  // 6.9. Fulfill the registration API request promise.
  [registerPromise fulfill:registeredInstallation];

  // 7. Wait for promises.
  XCTAssert(FBLWaitForPromisesWithTimeout(timeout));

  // 8. Check.
  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertNotEqualObjects(promise.value.firebaseInstallationID,
                           storedInstallation.firebaseInstallationID);
  XCTAssertEqualObjects(promise.value, registeredInstallation);
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
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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
      [FIRInstallationsErrorUtil APIErrorWithHTTPCode:FIRInstallationsHTTPCodesServerInternalError];
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
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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
  // 4.1. Expect new token to be stored on API response.
  OCMExpect([self.mockInstallationsStore saveInstallation:responseInstallation])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  [pendingAuthTokenAPIPromise fulfill:responseInstallation];

  // 5. Wait for operations to complete and check the result.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertTrue(promise.isFulfilled);
  [self waitForExpectations:@[ notificationExpectation ] timeout:0.5];

  OCMVerifyAll(self.mockInstallationsStore);
  OCMVerifyAll(self.mockAPIService);
  OCMVerifyAll(self.mockIIDStore);
}

- (NSArray<XCTestExpectation *> *)expectInstallationToBeDeletedLocally:
    (FIRInstallationsItem *)installation {
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

  return @[ notificationExpectation ];
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
  [self expectStoredIIDNotFound];

  // 1.4. API Service.
  OCMExpect([self.mockAPIService registerInstallation:[OCMArg any]])
      .andReturn([FBLPromise resolvedWith:[FIRInstallationsItem createRegisteredInstallationItem]]);

  // 2. Expect FIRInstallationIDDidChangeNotification to be sent.
  XCTestExpectation *notificationExpectation =
      [self installationIDDidChangeNotificationExpectation];

  // 3. Request FID.
  FBLPromise *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

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

#pragma mark - Helpers

- (void)expectInstallationsStoreGetInstallationNotFound {
  NSError *notFoundError =
      [FIRInstallationsErrorUtil installationItemNotFoundForAppID:self.appID appName:self.appName];
  FBLPromise *installationNotFoundPromise = [FBLPromise pendingPromise];
  [installationNotFoundPromise reject:notFoundError];

  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn(installationNotFoundPromise);
}

- (void)expectStoredIIDNotFound {
  FBLPromise *rejectedPromise = [FBLPromise pendingPromise];
  [rejectedPromise reject:[FIRInstallationsErrorUtil keychainErrorWithFunction:@"" status:-1]];
  OCMExpect([self.mockIIDStore existingIID]).andReturn(rejectedPromise);
  OCMExpect([self.mockIIDTokenStore existingIIDDefaultToken]).andReturn(rejectedPromise);
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

- (void)expectInstallationStoreToBeRequestedAndReturnInstallation:
    (FIRInstallationsItem *)storedInstallation {
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);
}

- (FIRInstallationsItem *)expectAuthTokenRefreshForInstallation:
    (FIRInstallationsItem *)installation {
  FIRInstallationsItem *responseInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  responseInstallation.authToken.token =
      [responseInstallation.authToken.token stringByAppendingString:@"_new"];
  OCMExpect([self.mockAPIService refreshAuthTokenForInstallation:installation])
      .andReturn([FBLPromise resolvedWith:responseInstallation]);

  // 1.3. Expect new token to be stored.
  OCMExpect([self.mockInstallationsStore saveInstallation:responseInstallation])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  return responseInstallation;
}

- (void)expectAPIServiceInitWithAPIKey:(NSString *)APIKey projectID:(NSString *)projectID {
  OCMExpect([self.mockAPIService initWithAPIKey:APIKey projectID:projectID]);
}

@end
