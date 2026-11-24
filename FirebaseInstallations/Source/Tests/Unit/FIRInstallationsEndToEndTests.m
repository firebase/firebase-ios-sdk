/*
 * Copyright 2026 Google LLC
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

// End-to-end tests of the Installations SDK that run the real `FIRInstallations`,
// `FIRInstallationsIDController`, `FIRInstallationsStore`, `FIRInstallationsAPIService` and backoff
// logic, replacing only the external dependencies with fakes:
// - the keychain, with `FIRInstallationsFakeSecureStorage`,
// - the Installations backend, with `FIRInstallationsFakeBackend`,
// - the legacy Instance ID data, with the fake IID stores below,
// - the heartbeat logger, with `FIRInstallationsTestHeartbeatLogger` below.
//
// They cover the scenarios of `FIRInstallationsIntegrationTests` without a
// GoogleService-Info.plist, network access, or keychain entitlements, so they also run in Swift
// Package Manager test bundles, which have no host app.

#import <XCTest/XCTest.h>

#import "FBLPromise+Testing.h"
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseInstallations/Source/Library/FIRInstallationsItem.h"
#import "FirebaseInstallations/Source/Library/IIDMigration/FIRInstallationsIIDStore.h"
#import "FirebaseInstallations/Source/Library/IIDMigration/FIRInstallationsIIDTokenStore.h"
#import "FirebaseInstallations/Source/Library/InstallationsAPI/FIRInstallationsAPIService.h"
#import "FirebaseInstallations/Source/Library/InstallationsIDController/FIRInstallationsBackoffController.h"
#import "FirebaseInstallations/Source/Library/InstallationsIDController/FIRInstallationsIDController.h"
#import "FirebaseInstallations/Source/Library/InstallationsStore/FIRInstallationsStore.h"
#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FIRInstallations.h"
#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FIRInstallationsAuthTokenResult.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallations+Tests.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsFakeBackend.h"
#import "FirebaseInstallations/Source/Tests/Utils/FIRInstallationsFakeSecureStorage.h"

static NSString *const kTestAPIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
static NSString *const kTestProjectID = @"project-id";
static NSString *const kTestGoogleAppID = @"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa";
static NSString *const kTestGCMSenderID = @"100000000000";
static NSString *const kTestHeartbeatHeader = @"test-heartbeat-header";

#pragma mark - Private initializers

@interface FIRInstallationsIDController (EndToEndTests)
- (instancetype)initWithGoogleAppID:(NSString *)appID
                            appName:(NSString *)appName
                 installationsStore:(FIRInstallationsStore *)installationsStore
                         APIService:(FIRInstallationsAPIService *)APIService
                           IIDStore:(FIRInstallationsIIDStore *)IIDStore
                      IIDTokenStore:(FIRInstallationsIIDTokenStore *)IIDTokenStore
                  backoffController:
                      (id<FIRInstallationsBackoffControllerProtocol>)backoffController;
@end

@interface FIRInstallationsAPIService (EndToEndTests)
- (instancetype)initWithURLSession:(NSURLSession *)URLSession
                            APIKey:(NSString *)APIKey
                         projectID:(NSString *)projectID
                   heartbeatLogger:(id<FIRHeartbeatLoggerProtocol>)heartbeatLogger;
@end

#pragma mark - Fakes

/// Legacy Instance ID data that the SDK migrates for the default app.
@interface FIRInstallationsFakeIIDStore : FIRInstallationsIIDStore
/// The IID to migrate, or `nil` if there's none.
@property(atomic, copy, nullable) NSString *IID;
@property(atomic) NSUInteger deleteCount;
@end

@implementation FIRInstallationsFakeIIDStore

- (FBLPromise<NSString *> *)existingIID {
  FBLPromise<NSString *> *promise = [FBLPromise pendingPromise];
  NSString *IID = self.IID;
  if (IID) {
    [promise fulfill:IID];
  } else {
    [promise reject:[NSError errorWithDomain:@"FIRInstallationsFakeIIDStore" code:0 userInfo:nil]];
  }
  return promise;
}

- (FBLPromise<NSNull *> *)deleteExistingIID {
  self.IID = nil;
  self.deleteCount += 1;
  return [FBLPromise resolvedWith:[NSNull null]];
}

@end

/// The legacy Instance ID default token that the SDK sends when it migrates an IID.
@interface FIRInstallationsFakeIIDTokenStore : FIRInstallationsIIDTokenStore
@property(atomic, copy, nullable) NSString *token;
@end

@implementation FIRInstallationsFakeIIDTokenStore

- (FBLPromise<NSString *> *)existingIIDDefaultToken {
  FBLPromise<NSString *> *promise = [FBLPromise pendingPromise];
  NSString *token = self.token;
  if (token) {
    [promise fulfill:token];
  } else {
    [promise reject:[NSError errorWithDomain:@"FIRInstallationsFakeIIDTokenStore"
                                        code:0
                                    userInfo:nil]];
  }
  return promise;
}

@end

/// A heartbeat logger whose logged heartbeat is flushed into the next header value, like
/// `FIRHeartbeatLogger`, without writing to the real heartbeat storage.
@interface FIRInstallationsTestHeartbeatLogger : NSObject <FIRHeartbeatLoggerProtocol>
@property(atomic, copy, nullable) NSString *pendingHeaderValue;
@end

@implementation FIRInstallationsTestHeartbeatLogger

- (void)log {
  self.pendingHeaderValue = kTestHeartbeatHeader;
}

- (FIRDailyHeartbeatCode)heartbeatCodeForToday {
  return FIRDailyHeartbeatCodeNone;
}

- (nullable NSString *)headerValue {
  @synchronized(self) {
    NSString *headerValue = self.pendingHeaderValue;
    self.pendingHeaderValue = nil;
    return headerValue;
  }
}

- (void)asyncHeaderValueWithCompletionHandler:(void (^)(NSString *_Nullable))completionHandler {
  completionHandler([self headerValue]);
}

@end

#pragma mark - Tests

@interface FIRInstallationsEndToEndTests : XCTestCase
@property(nonatomic) FIROptions *options;
@property(nonatomic) FIRInstallationsFakeBackend *backend;
@property(nonatomic) FIRInstallationsFakeSecureStorage *secureStorage;
@property(nonatomic) NSString *userDefaultsSuiteName;
@property(nonatomic) FIRInstallationsFakeIIDStore *IIDStore;
@property(nonatomic) FIRInstallationsFakeIIDTokenStore *IIDTokenStore;
@property(nonatomic) FIRInstallationsTestHeartbeatLogger *heartbeatLogger;
@property(nonatomic) FIRInstallations *installations;
@end

@implementation FIRInstallationsEndToEndTests

- (void)setUp {
  [super setUp];

  self.options = [[FIROptions alloc] initWithGoogleAppID:kTestGoogleAppID
                                             GCMSenderID:kTestGCMSenderID];
  self.options.APIKey = kTestAPIKey;
  self.options.projectID = kTestProjectID;

  self.backend = [[FIRInstallationsFakeBackend alloc] initWithProjectID:kTestProjectID
                                                                 APIKey:kTestAPIKey];
  self.secureStorage = [[FIRInstallationsFakeSecureStorage alloc] init];
  self.userDefaultsSuiteName = [@"com.firebase.FIRInstallationsEndToEndTests."
      stringByAppendingString:NSUUID.UUID.UUIDString];
  self.IIDStore = [[FIRInstallationsFakeIIDStore alloc] init];
  self.IIDTokenStore =
      [[FIRInstallationsFakeIIDTokenStore alloc] initWithGCMSenderID:kTestGCMSenderID];
  self.heartbeatLogger = [[FIRInstallationsTestHeartbeatLogger alloc] init];

  // Like `FIRInstallationsIntegrationTests`, start each test with a heartbeat to send.
  [self.heartbeatLogger log];

  self.installations = [self launchInstallations];
}

- (void)tearDown {
  // Let pending background work, such as registration, finish before the fakes go away.
  XCTAssert(FBLWaitForPromisesWithTimeout(10));

  self.installations = nil;
  self.backend = nil;
  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:self.userDefaultsSuiteName];
  [FIRApp resetApps];

  [super tearDown];
}

#pragma mark - Scenarios from FIRInstallationsIntegrationTests

- (void)testGetFID {
  NSString *FID1 = [self getFID];
  NSString *FID2 = [self getFID];

  XCTAssertEqualObjects(FID1, FID2);
  XCTAssertEqual(FID1.length, 22);

  // The installation is registered in the background.
  [self waitForBackgroundWork];
  XCTAssertTrue([self.backend hasInstallationWithFID:FID1]);
  NSArray<FIRInstallationsFakeBackendRequest *> *registrations = [self registrationRequests];
  XCTAssertEqual(registrations.count, 1);
  XCTAssertEqualObjects(registrations.firstObject.JSONBody[@"fid"], FID1);
  XCTAssertEqualObjects(registrations.firstObject.JSONBody[@"appId"], kTestGoogleAppID);

  // The heartbeat was flushed into the registration request.
  [self assertHeartbeatWasSentInRequest:registrations.firstObject];
}

- (void)testAuthToken {
  FIRInstallationsAuthTokenResult *tokenResult = [self getAuthTokenForcingRefresh:NO];

  XCTAssertGreaterThanOrEqual(tokenResult.authToken.length, 10);
  XCTAssertGreaterThanOrEqual([tokenResult.expirationDate timeIntervalSinceNow], 50 * 60);

  NSString *FID = [self getFID];
  XCTAssertEqualObjects(tokenResult.authToken, [self.backend authTokenForFID:FID]);

  // The token came from the registration response, so no token request was needed.
  XCTAssertEqual([self registrationRequests].count, 1);
  XCTAssertEqual([self authTokenRequests].count, 0);
  [self assertHeartbeatWasSentInRequest:[self registrationRequests].firstObject];
}

- (void)testDeleteInstallation {
  NSString *FIDBefore = [self getFID];
  FIRInstallationsAuthTokenResult *authTokenBefore = [self getAuthTokenForcingRefresh:NO];
  NSString *refreshTokenBefore = [self.backend refreshTokenForFID:FIDBefore];

  [self deleteInstallation];

  // The backend deleted the installation, authorized with its refresh token.
  XCTAssertFalse([self.backend hasInstallationWithFID:FIDBefore]);
  NSArray<FIRInstallationsFakeBackendRequest *> *deletions = [self deleteRequests];
  XCTAssertEqual(deletions.count, 1);
  XCTAssertTrue([deletions.firstObject.path hasSuffix:FIDBefore]);
  XCTAssertEqualObjects([deletions.firstObject valueForHeader:@"Authorization"],
                        [@"FIS_v2 " stringByAppendingString:refreshTokenBefore]);
  // The legacy IID is deleted together with the installation of the default app.
  XCTAssertEqual(self.IIDStore.deleteCount, 1);

  NSString *FIDAfter = [self getFID];
  FIRInstallationsAuthTokenResult *authTokenAfter = [self getAuthTokenForcingRefresh:NO];

  XCTAssertNotEqualObjects(FIDBefore, FIDAfter);
  XCTAssertNotEqualObjects(authTokenBefore.authToken, authTokenAfter.authToken);
  XCTAssertNotEqualObjects(authTokenBefore.expirationDate, authTokenAfter.expirationDate);
  XCTAssertTrue([self.backend hasInstallationWithFID:FIDAfter]);
  XCTAssertEqual([self registrationRequests].count, 2);
  XCTAssertEqual(self.secureStorage.itemCount, 1);
}

- (void)testInstallationsWithApp {
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp1"];
  [self assertInstallationsWithAppNamed:@"testInstallationsWithApp2"];

  // Wait for finishing all background operations.
  [self waitForBackgroundWork];
}

- (void)testDefaultAppInstallation {
  [FIRApp configureWithOptions:self.options];

  FIRInstallations *installations = [FIRInstallations installations];
  XCTAssertNotNil(installations);
  XCTAssertEqualObjects(installations.appOptions.googleAppID,
                        [FIRApp defaultApp].options.googleAppID);
  XCTAssertEqualObjects(installations.appName, [FIRApp defaultApp].name);

  // Wait for finishing all background operations.
  [self waitForBackgroundWork];
}

#pragma mark - Persistence across launches

- (void)testStoredInstallationIsReusedAfterRelaunch {
  NSString *FID = [self getFID];
  FIRInstallationsAuthTokenResult *authToken = [self getAuthTokenForcingRefresh:NO];
  NSUInteger requestCount = self.backend.requests.count;

  // A new SDK stack reading the same keychain and user defaults, as after an app relaunch.
  self.installations = [self launchInstallations];

  XCTAssertEqualObjects([self getFID], FID);
  XCTAssertEqualObjects([self getAuthTokenForcingRefresh:NO].authToken, authToken.authToken);
  [self waitForBackgroundWork];
  XCTAssertEqual(self.backend.requests.count, requestCount);
}

- (void)testMissingUserDefaultsMarkerCreatesNewInstallation {
  NSString *FIDBefore = [self getFID];
  [self waitForBackgroundWork];

  // The keychain outlives an app reinstall but user defaults don't, so a missing user defaults
  // marker makes the SDK ignore the stored installation.
  NSString *itemID = [FIRInstallationsItem identifierWithAppID:kTestGoogleAppID
                                                       appName:kFIRDefaultAppName];
  NSUserDefaults *userDefaults =
      [[NSUserDefaults alloc] initWithSuiteName:self.userDefaultsSuiteName];
  XCTAssertNotNil([userDefaults objectForKey:itemID]);
  [userDefaults removeObjectForKey:itemID];
  self.installations = [self launchInstallations];

  NSString *FIDAfter = [self getFID];
  [self waitForBackgroundWork];

  XCTAssertNotEqualObjects(FIDAfter, FIDBefore);
  XCTAssertTrue([self.backend hasInstallationWithFID:FIDAfter]);
  // The stored installation is replaced, not added.
  XCTAssertEqual(self.secureStorage.itemCount, 1);
}

- (void)testUndecodableStoredInstallationCreatesNewInstallation {
  NSString *FIDBefore = [self getFID];
  [self waitForBackgroundWork];

  NSString *itemID = [FIRInstallationsItem identifierWithAppID:kTestGoogleAppID
                                                       appName:kFIRDefaultAppName];
  XCTAssertNotNil([self.secureStorage dataForKey:itemID]);
  [self.secureStorage setData:[@"not an archive" dataUsingEncoding:NSUTF8StringEncoding]
                       forKey:itemID];
  self.installations = [self launchInstallations];

  NSString *FIDAfter = [self getFID];
  [self waitForBackgroundWork];

  XCTAssertNotEqualObjects(FIDAfter, FIDBefore);
  XCTAssertTrue([self.backend hasInstallationWithFID:FIDAfter]);

  // The new installation was saved in a readable form.
  self.installations = [self launchInstallations];
  XCTAssertEqualObjects([self getFID], FIDAfter);
}

#pragma mark - Backend interaction

- (void)testAuthTokenForcingRefreshRequestsNewToken {
  NSString *FID = [self getFID];
  FIRInstallationsAuthTokenResult *tokenBefore = [self getAuthTokenForcingRefresh:NO];

  FIRInstallationsAuthTokenResult *tokenAfter = [self getAuthTokenForcingRefresh:YES];

  XCTAssertNotEqualObjects(tokenAfter.authToken, tokenBefore.authToken);
  XCTAssertEqualObjects(tokenAfter.authToken, [self.backend authTokenForFID:FID]);
  NSArray<FIRInstallationsFakeBackendRequest *> *tokenRequests = [self authTokenRequests];
  XCTAssertEqual(tokenRequests.count, 1);
  XCTAssertEqualObjects([tokenRequests.firstObject valueForHeader:@"Authorization"],
                        [@"FIS_v2 " stringByAppendingString:[self.backend refreshTokenForFID:FID]]);
}

- (void)testInstallationUnknownToBackendIsReplacedOnTokenRefresh {
  NSString *FIDBefore = [self getFID];
  [self getAuthTokenForcingRefresh:NO];

  // The backend no longer knows the installation, so the token request fails with 404 and the SDK
  // registers a new installation.
  [self.backend forgetInstallationWithFID:FIDBefore];
  FIRInstallationsAuthTokenResult *token = [self getAuthTokenForcingRefresh:YES];

  NSString *FIDAfter = [self getFID];
  XCTAssertNotEqualObjects(FIDAfter, FIDBefore);
  XCTAssertTrue([self.backend hasInstallationWithFID:FIDAfter]);
  XCTAssertEqualObjects(token.authToken, [self.backend authTokenForFID:FIDAfter]);
}

- (void)testFIDAssignedByBackendIsUsed {
  NSString *assignedFID = @"fAssignedByBackend0001";
  self.backend.FIDForNextRegistration = assignedFID;

  __block NSUInteger FIDChangeCount = 0;
  id observer = [[NSNotificationCenter defaultCenter]
      addObserverForName:FIRInstallationIDDidChangeNotification
                  object:nil
                   queue:nil
              usingBlock:^(NSNotification *notification) {
                @synchronized(self) {
                  FIDChangeCount += 1;
                }
              }];

  [self getAuthTokenForcingRefresh:NO];
  [self waitForBackgroundWork];
  [[NSNotificationCenter defaultCenter] removeObserver:observer];

  XCTAssertEqualObjects([self getFID], assignedFID);
  XCTAssertTrue([self.backend hasInstallationWithFID:assignedFID]);
  // One notification for the FID created on the device and one for the FID assigned by the backend.
  @synchronized(self) {
    XCTAssertEqual(FIDChangeCount, 2);
  }
}

- (void)testIIDIsMigratedForDefaultApp {
  NSString *IID = @"cLegacyIIDValue0000001";
  self.IIDStore.IID = IID;
  self.IIDTokenStore.token = @"legacy-iid-default-token";

  XCTAssertEqualObjects([self getFID], IID);
  [self waitForBackgroundWork];

  NSArray<FIRInstallationsFakeBackendRequest *> *registrations = [self registrationRequests];
  XCTAssertEqual(registrations.count, 1);
  XCTAssertEqualObjects(registrations.firstObject.JSONBody[@"fid"], IID);
  XCTAssertEqualObjects(
      [registrations.firstObject valueForHeader:@"x-goog-fis-ios-iid-migration-auth"],
      @"legacy-iid-default-token");
  XCTAssertTrue([self.backend hasInstallationWithFID:IID]);
}

#pragma mark - Helpers

/// Creates the SDK stack on top of the fakes, sharing the storage of earlier launches.
- (FIRInstallations *)launchInstallations {
  // `FIRInstallationsStore` uses the access group as the user defaults suite name, so a unique
  // name keeps the tests' user defaults apart. The fake secure storage ignores the access group.
  FIRInstallationsStore *store =
      [[FIRInstallationsStore alloc] initWithSecureStorage:self.secureStorage
                                               accessGroup:self.userDefaultsSuiteName];
  FIRInstallationsAPIService *APIService =
      [[FIRInstallationsAPIService alloc] initWithURLSession:self.backend.URLSession
                                                      APIKey:kTestAPIKey
                                                   projectID:kTestProjectID
                                             heartbeatLogger:self.heartbeatLogger];
  FIRInstallationsIDController *IDController = [[FIRInstallationsIDController alloc]
      initWithGoogleAppID:kTestGoogleAppID
                  appName:kFIRDefaultAppName
       installationsStore:store
               APIService:APIService
                 IIDStore:self.IIDStore
            IIDTokenStore:self.IIDTokenStore
        backoffController:[[FIRInstallationsBackoffController alloc] init]];
  return [[FIRInstallations alloc] initWithAppOptions:self.options
                                              appName:kFIRDefaultAppName
                            installationsIDController:IDController
                                    prefetchAuthToken:NO];
}

- (NSString *)getFID {
  XCTestExpectation *expectation =
      [self expectationWithDescription:[NSString stringWithFormat:@"FID %@", self.name]];

  __block NSString *retrievedID;
  [self.installations
      installationIDWithCompletion:^(NSString *_Nullable identifier, NSError *_Nullable error) {
        XCTAssertNotNil(identifier);
        XCTAssertNil(error);
        XCTAssertEqual(identifier.length, 22);

        retrievedID = identifier;

        [expectation fulfill];
      }];

  [self waitForExpectations:@[ expectation ] timeout:5];

  return retrievedID;
}

- (FIRInstallationsAuthTokenResult *)getAuthTokenForcingRefresh:(BOOL)forceRefresh {
  XCTestExpectation *expectation = [self expectationWithDescription:@"authTokenExpectation"];

  __block FIRInstallationsAuthTokenResult *retrievedTokenResult;
  [self.installations
      authTokenForcingRefresh:forceRefresh
                   completion:^(FIRInstallationsAuthTokenResult *_Nullable tokenResult,
                                NSError *_Nullable error) {
                     XCTAssertNil(error);
                     XCTAssertNotNil(tokenResult);
                     XCTAssertGreaterThanOrEqual(tokenResult.authToken.length, 10);
                     XCTAssertGreaterThanOrEqual([tokenResult.expirationDate timeIntervalSinceNow],
                                                 50 * 60);

                     retrievedTokenResult = tokenResult;

                     [expectation fulfill];
                   }];

  [self waitForExpectations:@[ expectation ] timeout:5];

  return retrievedTokenResult;
}

- (void)deleteInstallation {
  XCTestExpectation *expectation = [self expectationWithDescription:@"Delete Installation"];
  [self.installations deleteWithCompletion:^(NSError *_Nullable error) {
    XCTAssertNil(error);
    [expectation fulfill];
  }];
  [self waitForExpectations:@[ expectation ] timeout:5];
}

- (void)waitForBackgroundWork {
  XCTAssert(FBLWaitForPromisesWithTimeout(10));
}

- (void)assertHeartbeatWasSentInRequest:(FIRInstallationsFakeBackendRequest *)request {
  XCTAssertEqualObjects([request valueForHeader:@"X-firebase-client"], kTestHeartbeatHeader);
  XCTAssertNil(self.heartbeatLogger.pendingHeaderValue);
}

- (NSArray<FIRInstallationsFakeBackendRequest *> *)registrationRequests {
  NSPredicate *predicate = [NSPredicate
      predicateWithBlock:^BOOL(FIRInstallationsFakeBackendRequest *request, id bindings) {
        return [request.HTTPMethod isEqualToString:@"POST"] &&
               [request.path hasSuffix:@"/installations"];
      }];
  return [self.backend.requests filteredArrayUsingPredicate:predicate];
}

- (NSArray<FIRInstallationsFakeBackendRequest *> *)authTokenRequests {
  NSPredicate *predicate = [NSPredicate
      predicateWithBlock:^BOOL(FIRInstallationsFakeBackendRequest *request, id bindings) {
        return [request.HTTPMethod isEqualToString:@"POST"] &&
               [request.path hasSuffix:@"/authTokens:generate"];
      }];
  return [self.backend.requests filteredArrayUsingPredicate:predicate];
}

- (NSArray<FIRInstallationsFakeBackendRequest *> *)deleteRequests {
  NSPredicate *predicate = [NSPredicate
      predicateWithBlock:^BOOL(FIRInstallationsFakeBackendRequest *request, id bindings) {
        return [request.HTTPMethod isEqualToString:@"DELETE"];
      }];
  return [self.backend.requests filteredArrayUsingPredicate:predicate];
}

- (FIRInstallations *)assertInstallationsWithAppNamed:(NSString *)appName {
  [FIRApp configureWithName:appName options:self.options];
  FIRApp *app = [FIRApp appNamed:appName];
  FIRInstallations *installations = [FIRInstallations installationsWithApp:app];

  XCTAssertNotNil(installations);
  XCTAssertEqualObjects(installations.appOptions.googleAppID, app.options.googleAppID);
  XCTAssertEqualObjects(installations.appName, app.name);

  return installations;
}

@end
