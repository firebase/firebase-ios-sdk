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

#import <FirebaseRemoteConfig/FIRRemoteConfig.h>
#import "FirebaseRemoteConfig/Sources/Private/FIRRemoteConfig_Private.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNUserDefaultsManager.h"

#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

#import <FirebaseCore/FIRAppInternal.h>
#import <FirebaseCore/FIRLogger.h>
#import <FirebaseCore/FIROptions.h>
#import <FirebaseInstallations/FirebaseInstallations.h>
#import <GoogleUtilities/GULNSData+zlib.h>
#import <OCMock/OCMock.h>

@interface RCNConfigFetch (ForTest)
- (instancetype)initWithContent:(RCNConfigContent *)content
                      DBManager:(RCNConfigDBManager *)DBManager
                       settings:(RCNConfigSettings *)settings
                     experiment:(RCNConfigExperiment *)experiment
                          queue:(dispatch_queue_t)queue
                      namespace:firebaseNamespace
                            app:firebaseApp;
@end

@interface RCNConfigDBManager (Test)
- (void)removeDatabaseOnDatabaseQueueAtPath:(NSString *)path;
@end

@interface RCNUserDefaultsManager (Test)
+ (NSUserDefaults *)sharedUserDefaultsForBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface FIRInstallationsAuthTokenResult (Test)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;
@end

typedef NS_ENUM(NSInteger, RCNTestRCInstance) {
  RCNTestRCInstanceDefault,
  RCNTestRCNumTotalInstances,  // TODO(mandard): Remove once OCMock issue is resolved (#4877).
  RCNTestRCInstanceSecondNamespace,
  RCNTestRCInstanceSecondApp,
};

@class FIRInstallationsIDController;
@interface FIRInstallations (Tests)
- (instancetype)initWithAppOptions:(FIROptions *)appOptions
                           appName:(NSString *)appName
         installationsIDController:(FIRInstallationsIDController *)installationsIDController
                 prefetchAuthToken:(BOOL)prefetchAuthToken;
@end

@interface RCNInstallationsTests : XCTestCase {
  NSTimeInterval _expectationTimeout;
  NSTimeInterval _checkCompletionTimeout;
  NSMutableArray<FIRRemoteConfig *> *_configInstances;
  NSMutableArray<NSDictionary<NSString *, NSString *> *> *_entries;
  NSMutableArray<NSDictionary<NSString *, id> *> *_response;
  NSMutableArray<NSData *> *_responseData;
  NSMutableArray<NSURLResponse *> *_URLResponse;
  NSMutableArray<RCNConfigFetch *> *_configFetch;
  RCNConfigDBManager *_DBManager;
  NSUserDefaults *_userDefaults;
  NSString *_userDefaultsSuiteName;
  NSString *_DBPath;

  id _installationsMock;
}
@end

@implementation RCNInstallationsTests

- (void)setUpConfigMock {
  FIRSetLoggerLevel(FIRLoggerLevelMax);
  _expectationTimeout = 5;
  _checkCompletionTimeout = 1.0;
  [FIRApp configureWithOptions:[self firstAppOptions]];

  // Always remove the database at the start of testing.
  _DBPath = [RCNTestUtilities remoteConfigPathForTestDatabase];
  id classMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([classMock remoteConfigPathForDatabase]).andReturn(_DBPath);
  _DBManager = [[RCNConfigDBManager alloc] init];

  _userDefaultsSuiteName = [RCNTestUtilities userDefaultsSuiteNameForTestSuite];
  _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:_userDefaultsSuiteName];
  id userDefaultsClassMock = OCMClassMock([RCNUserDefaultsManager class]);
  OCMStub([userDefaultsClassMock sharedUserDefaultsForBundleIdentifier:[OCMArg any]])
      .andReturn(_userDefaults);

  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:_DBManager];
  _configInstances = [[NSMutableArray alloc] initWithCapacity:3];
  _entries = [[NSMutableArray alloc] initWithCapacity:3];
  _response = [[NSMutableArray alloc] initWithCapacity:3];
  _responseData = [[NSMutableArray alloc] initWithCapacity:3];
  _URLResponse = [[NSMutableArray alloc] initWithCapacity:3];
  _configFetch = [[NSMutableArray alloc] initWithCapacity:3];

  // Populate the default, second app, second namespace instances.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    // Fake a response for default instance.
    NSMutableDictionary<NSString *, NSString *> *valuesDict = [[NSMutableDictionary alloc] init];
    for (int count = 1; count <= 100; count++) {
      NSString *key = [NSString stringWithFormat:@"key%d-%d", count, i];
      NSString *value = [NSString stringWithFormat:@"value%d-%d", count, i];
      valuesDict[key] = value;
    }
    _entries[i] = valuesDict;

    NSString *currentAppName = nil;
    FIROptions *currentOptions = nil;
    NSString *currentNamespace = nil;
    switch (i) {
      case RCNTestRCInstanceSecondNamespace:
        currentAppName = RCNTestsDefaultFIRAppName;
        currentOptions = [self firstAppOptions];
        currentNamespace = RCNTestsPerfNamespace;
        break;
      case RCNTestRCInstanceSecondApp:
        currentAppName = RCNTestsSecondFIRAppName;
        currentOptions = [self secondAppOptions];
        currentNamespace = FIRNamespaceGoogleMobilePlatform;
        break;
      case RCNTestRCInstanceDefault:
      default:
        currentAppName = RCNTestsDefaultFIRAppName;
        currentOptions = [self firstAppOptions];
        currentNamespace = RCNTestsFIRNamespace;
        break;
    }
    NSString *fullyQualifiedNamespace =
        [NSString stringWithFormat:@"%@:%@", currentNamespace, currentAppName];
    FIRRemoteConfig *config =
        OCMPartialMock([[FIRRemoteConfig alloc] initWithAppName:currentAppName
                                                     FIROptions:currentOptions
                                                      namespace:currentNamespace
                                                      DBManager:_DBManager
                                                  configContent:configContent
                                                      analytics:nil]);

    _configInstances[i] = config;
    RCNConfigSettings *settings =
        [[RCNConfigSettings alloc] initWithDatabaseManager:_DBManager
                                                 namespace:fullyQualifiedNamespace
                                           firebaseAppName:currentAppName
                                               googleAppID:currentOptions.googleAppID];
    dispatch_queue_t queue = dispatch_queue_create(
        [[NSString stringWithFormat:@"testqueue: %d", i] cStringUsingEncoding:NSUTF8StringEncoding],
        DISPATCH_QUEUE_SERIAL);
    _configFetch[i] = OCMPartialMock([[RCNConfigFetch alloc] initWithContent:configContent
                                                                   DBManager:_DBManager
                                                                    settings:settings
                                                                   analytics:nil
                                                                  experiment:nil
                                                                       queue:queue
                                                                   namespace:fullyQualifiedNamespace
                                                                     options:currentOptions]);
  }
}

// Mock instance ID methods.
- (void)mockInstanceIDMethodForTokenAndIdentity:(nullable NSString *)token
                                     tokenError:(nullable NSError *)tokenError
                                       identity:(nullable NSString *)identity
                                  identityError:(nullable NSError *)identityError {
  // Mock the installations retreival method.
  _installationsMock = OCMClassMock([FIRInstallations class]);

  id installationIDCompletionArg =
      [OCMArg checkWithBlock:^BOOL(FIRInstallationsIDHandler completion) {
        if (completion) {
          completion(identity, identityError);
        }
        return YES;
      }];
  OCMStub([_installationsMock installationIDWithCompletion:installationIDCompletionArg]);

  FIRInstallationsAuthTokenResult *tokenResult;
  if (token) {
    tokenResult = [[FIRInstallationsAuthTokenResult alloc] initWithToken:token
                                                          expirationDate:[NSDate distantFuture]];
  }

  id authTokenCompletionArg =
      [OCMArg checkWithBlock:^BOOL(FIRInstallationsTokenHandler completion) {
        if (completion) {
          completion(tokenResult, tokenError);
        }
        return YES;
      }];
  OCMStub([_installationsMock authTokenWithCompletion:authTokenCompletionArg]);

  OCMStub([_installationsMock installationsWithApp:[OCMArg any]]).andReturn(_installationsMock);

  [self setUpConfigMock];
}

- (void)tearDown {
  [_DBManager removeDatabaseOnDatabaseQueueAtPath:_DBPath];
  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:_userDefaultsSuiteName];
  [FIRApp resetApps];
  [_installationsMock stopMocking];
  _installationsMock = nil;
  [super tearDown];
}

// Instance ID token is nil. Error is not nil. Verify fetch fails.
- (void)testNilInstallationsAuthTokenAndError {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  // Set the token as nil.
  [self
      mockInstanceIDMethodForTokenAndIdentity:nil
                                   tokenError:[NSError
                                                  errorWithDomain:kFirebaseInstallationsErrorDomain
                                                             code:FIRInstallationsErrorCodeUnknown
                                                         userInfo:nil]
                                     identity:nil
                                identityError:nil];
  // Test for each RC FIRApp, namespace instance.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertNotNil(error);
          [expectations[i] fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// Test IID error. Subsequent request also fails with same error (b/148975341).
- (void)testMultipleFetchCallsFailing {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  // Set the token as nil.
  NSError *tokenError = [NSError errorWithDomain:kFirebaseInstallationsErrorDomain
                                            code:FIRInstallationsErrorCodeUnknown
                                        userInfo:nil];
  [self mockInstanceIDMethodForTokenAndIdentity:nil
                                     tokenError:tokenError
                                       identity:nil
                                  identityError:nil];
  // Test for each RC FIRApp, namespace instance.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertNotNil(error);
          XCTAssert([[error.userInfo objectForKey:@"NSLocalizedDescription"]
              containsString:@"Failed to get installations token"]);
          // Make a second fetch call.
          [self->_configInstances[i]
              fetchWithExpirationDuration:43200
                        completionHandler:^void(FIRRemoteConfigFetchStatus status, NSError *error) {
                          XCTAssertNotNil(error);
                          XCTAssert([[error.userInfo objectForKey:@"NSLocalizedDescription"]
                              containsString:@"Failed to get installations token"]);
                          [expectations[i] fulfill];
                        }];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// Instance ID token is not nil. Error is not nil. Verify fetch fails.
- (void)testValidInstanceIDTokenAndValidError {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  // Test for each RC FIRApp, namespace instance.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    // Set the token as nil.
    NSError *tokenError = [NSError errorWithDomain:kFirebaseInstallationsErrorDomain
                                              code:FIRInstallationsErrorCodeUnknown
                                          userInfo:nil];
    [self mockInstanceIDMethodForTokenAndIdentity:@"abcd"
                                       tokenError:tokenError
                                         identity:nil
                                    identityError:nil];

    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertNotNil(error);
          [expectations[i] fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// Instance ID token is nil. Error is nil. Verify fetch fails.
- (void)testNilInstanceIDTokenAndNilError {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  // Test for each RC FIRApp, namespace instance.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    // Set the token as nil.
    [self mockInstanceIDMethodForTokenAndIdentity:nil
                                       tokenError:nil
                                         identity:nil
                                    identityError:nil];

    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertNotNil(error);
          [expectations[i] fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// Instance ID token is valid. InstanceID is nil with no error. Verify fetch fails.
- (void)testNilInstanceIDWithValidInstanceIDToken {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  // Test for each RC FIRApp, namespace instance.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    // Set the token as nil.
    [self mockInstanceIDMethodForTokenAndIdentity:@"abcd"
                                       tokenError:nil
                                         identity:nil
                                    identityError:nil];

    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertNotNil(error);
          [expectations[i] fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// Instance ID is not nil, but IID SDK returns an error. Also token is valid.
- (void)testValidInstanceIDAndError {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  // Test for each RC FIRApp, namespace instance.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    // Set the token as nil.
    NSError *identityError = [NSError errorWithDomain:kFirebaseInstallationsErrorDomain
                                                 code:FIRInstallationsErrorCodeUnknown
                                             userInfo:nil];
    [self mockInstanceIDMethodForTokenAndIdentity:@"abcd"
                                       tokenError:nil
                                         identity:@"test-id"
                                    identityError:identityError];

    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertNotNil(error);
          [expectations[i] fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

#pragma mark - Test Helpers

- (FIROptions *)firstAppOptions {
  // TODO: Evaluate if we want to hardcode things here instead.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123abc"
                                                    GCMSenderID:@"correct_gcm_sender_id"];
  options.APIKey = @"correct_api_key";
  options.projectID = @"abc-xyz-123";
  return options;
}

- (FIROptions *)secondAppOptions {
  FIROptions *options =
      [[FIROptions alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]]
                                                     pathForResource:@"SecondApp-GoogleService-Info"
                                                              ofType:@"plist"]];
  XCTAssertNotNil(options);
  return options;
}

@end
