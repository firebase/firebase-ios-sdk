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

#import "FIRInstallationsAPIService.h"
#import "FIRInstallationsAuthTokenResultInternal.h"
#import "FIRInstallationsErrorUtil.h"
#import "FIRInstallationsIDController.h"
#import "FIRInstallationsStore.h"
#import "FIRInstallationsStoredAuthToken.h"

@interface FIRInstallationsIDController (Tests)
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                 installationsStore:(FIRInstallationsStore *)installationsStore
                         APIService:(FIRInstallationsAPIService *)APIService;
@end

@interface FIRInstallationsIDControllerTests : XCTestCase
@property(nonatomic) FIRInstallationsIDController *controller;
@property(nonatomic) id mockInstallationsStore;
@property(nonatomic) id mockAPIService;
@property(nonatomic) NSString *appID;
@property(nonatomic) NSString *appName;
@end

@implementation FIRInstallationsIDControllerTests

- (void)setUp {
  self.appID = @"appID";
  self.appName = @"appName";
  self.mockInstallationsStore = OCMClassMock([FIRInstallationsStore class]);
  self.mockAPIService = OCMClassMock([FIRInstallationsAPIService class]);
  self.controller =
      [[FIRInstallationsIDController alloc] initWithGoogleAppID:self.appID
                                                        appName:self.appName
                                             installationsStore:self.mockInstallationsStore
                                                     APIService:self.mockAPIService];
}

- (void)tearDown {
  self.controller = nil;
  self.mockAPIService = nil;
  self.mockInstallationsStore = nil;
  self.appID = nil;
  self.appName = nil;
}

#pragma mark - Get Installation

- (void)testGetInstallationItem_WhenFIDExists_ThenItIsReturned {
  FIRInstallationsItem *storedInstallations =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallations]);

  FBLPromise<FIRInstallationsItem *> *promise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(promise.error);
  XCTAssertEqual(promise.value, storedInstallations);

  OCMVerifyAll(self.mockInstallationsStore);
}

- (void)testGetInstallationItem_WhenNoFIDAndNoIID_ThenFIDIsCreatedAndRegistered {
  // 1. Stub store get installation.
  NSError *notFoundError =
      [FIRInstallationsErrorUtil installationItemNotFoundForAppID:self.appID appName:self.appName];
  FBLPromise *installationNotFoundPromise = [FBLPromise pendingPromise];
  [installationNotFoundPromise reject:notFoundError];

  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn(installationNotFoundPromise);

  // 2. Stub store save installation.
  __block FIRInstallationsItem *createdInstallation;

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  XCTAssertEqualObjects([obj class], [FIRInstallationsItem class]);
                  XCTAssertEqualObjects(obj.appID, self.appID);
                  XCTAssertEqualObjects(obj.firebaseAppName, self.appName);
                  XCTAssertEqual(obj.registrationStatus, FIRInstallationStatusUnregistered);
                  XCTAssertNotNil(obj.firebaseInstallationID);

                  createdInstallation = obj;
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 3. Stub API register installation.
  // 3.1. Verify installation to be registered.
  id registerInstallationValidation = [OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
    XCTAssertEqualObjects([obj class], [FIRInstallationsItem class]);
    XCTAssertEqualObjects(obj.appID, self.appID);
    XCTAssertEqualObjects(obj.firebaseAppName, self.appName);
    XCTAssertEqual(obj.registrationStatus, FIRInstallationStatusUnregistered);
    XCTAssertEqual(obj.firebaseInstallationID.length, 22);
    return YES;
  }];

  // 3.2. Expect for `registerInstallation` to be called.
  FBLPromise<FIRInstallationsItem *> *registerPromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockAPIService registerInstallation:registerInstallationValidation])
      .andReturn(registerPromise);

  // 4. Call get installation and check.
  FBLPromise<FIRInstallationsItem *> *getInstallationPromise =
      [self.controller getInstallationItem];

  // 4.1. Wait for the stored item to be read and saved.
  OCMVerifyAllWithDelay(self.mockInstallationsStore, 0.5);

  // 4.2. Wait for `registerInstallation` to be called.
  OCMVerifyAllWithDelay(self.mockAPIService, 0.5);

  // 4.3. Expect for the registered installation to be saved.
  FIRInstallationsItem *registeredInstallation = [FIRInstallationsItem
      createRegisteredInstallationItemWithAppID:createdInstallation.appID
                                        appName:createdInstallation.firebaseAppName];

  OCMExpect([self.mockInstallationsStore
                saveInstallation:[OCMArg checkWithBlock:^BOOL(FIRInstallationsItem *obj) {
                  XCTAssertEqual(registeredInstallation, obj);
                  return YES;
                }]])
      .andReturn([FBLPromise resolvedWith:[NSNull null]]);

  // 4.5. Resolve `registerPromise` to simulate finished registration.
  [registerPromise fulfill:registeredInstallation];

  // 4.4. Wait for the task to complete.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(getInstallationPromise.error);
  // We expect the initially created installation to be returned - must not wait for registration to
  // complete here.
  XCTAssertEqual(getInstallationPromise.value, createdInstallation);

  // 4.5. Verify registered installation was saved.
  OCMVerifyAll(self.mockInstallationsStore);
}

- (void)testGetInstallationItem_WhenCalledSeveralTimes_OnlyOneOperationIsPerformed {
  // 1. Expect the installation to be requested from the store only once.
  FIRInstallationsItem *storedInstallation1 =
      [FIRInstallationsItem createRegisteredInstallationItem];
  FBLPromise<FIRInstallationsItem *> *pendingStorePromise = [FBLPromise pendingPromise];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn(pendingStorePromise);

  // 2. Request installation n times
  NSInteger requestCount = 10;
  NSMutableArray *instllationPromises = [NSMutableArray arrayWithCapacity:requestCount];
  for (NSInteger i = 0; i < requestCount; i++) {
    [instllationPromises addObject:[self.controller getInstallationItem]];
  }

  // 3. Resolve store promise.
  [pendingStorePromise fulfill:storedInstallation1];

  // 4. Wait for operation to be completed and check.
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  for (FBLPromise<FIRInstallationsItem *> *installationPromise in instllationPromises) {
    XCTAssertNil(installationPromise.error);
    XCTAssertEqual(installationPromise.value, storedInstallation1);
  }

  OCMVerifyAll(self.mockInstallationsStore);

  // 5. Check that a new request is performed once prevoius finished.
  FIRInstallationsItem *storedInstallation2 =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation2]);

  FBLPromise<FIRInstallationsItem *> *installationPromise = [self.controller getInstallationItem];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));

  XCTAssertNil(installationPromise.error);
  XCTAssertEqual(installationPromise.value, storedInstallation2);

  OCMVerifyAll(self.mockInstallationsStore);
}

#pragma mark - Get Auth Token

- (void)testGetAuthToken_WhenValidInstallationExists_ThenItIsReturned {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];
  OCMExpect([self.mockInstallationsStore installationForAppID:self.appID appName:self.appName])
      .andReturn([FBLPromise resolvedWith:storedInstallation]);

  // 2. Request auth token.
  FBLPromise<FIRInstallationsAuthTokenResult *> *promise =
      [self.controller getAuthTokenForcingRefresh:NO];

  // 3. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 4. Check.
  OCMVerifyAll(self.mockInstallationsStore);

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertEqualObjects(promise.value.authToken, storedInstallation.authToken.token);
  XCTAssertEqualObjects(promise.value.expirationDate, storedInstallation.authToken.expirationDate);
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
  FBLPromise<FIRInstallationsAuthTokenResult *> *promise =
      [self.controller getAuthTokenForcingRefresh:NO];

  // 3. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 4. Check.
  OCMVerifyAll(self.mockInstallationsStore);

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertEqualObjects(promise.value.authToken, responseInstallation.authToken.token);
  XCTAssertEqualObjects(promise.value.expirationDate,
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
  FBLPromise<FIRInstallationsAuthTokenResult *> *promise =
      [self.controller getAuthTokenForcingRefresh:YES];

  // 3. Wait for the promise to resolve.
  FBLWaitForPromisesWithTimeout(0.5);

  // 4. Check.
  OCMVerifyAll(self.mockInstallationsStore);

  XCTAssertNil(promise.error);
  XCTAssertNotNil(promise.value);

  XCTAssertEqualObjects(promise.value.authToken, responseInstallation.authToken.token);
  XCTAssertEqualObjects(promise.value.expirationDate,
                        responseInstallation.authToken.expirationDate);
}

// TODO: Add error tests.

- (void)testGetAuthToken_WhenCalledSeveralTimes_OnlyOneOperationIsPerformed {
  // 1. Expect installation to be requested from the store.
  FIRInstallationsItem *storedInstallation =
      [FIRInstallationsItem createRegisteredInstallationItem];

  FBLPromise *storagePendingPromise = [FBLPromise pendingPromise];
  // Expect the instalation to be requested only once.
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

  for (FBLPromise<FIRInstallationsAuthTokenResult *> *authPromise in authTokenPromises) {
    XCTAssertNil(authPromise.error);
    XCTAssertNotNil(authPromise.value);

    XCTAssertEqualObjects(authPromise.value.authToken, storedInstallation.authToken.token);
    XCTAssertEqualObjects(authPromise.value.expirationDate,
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

  for (FBLPromise<FIRInstallationsAuthTokenResult *> *authPromise in authTokenPromises) {
    XCTAssertNil(authPromise.error);
    XCTAssertNotNil(authPromise.value);

    XCTAssertEqualObjects(authPromise.value.authToken, responseInstallation.authToken.token);
    XCTAssertEqualObjects(authPromise.value.expirationDate,
                          responseInstallation.authToken.expirationDate);
  }
}

@end
