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

#import <OCMock/OCMStubRecorder.h>
#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

// Import Swift testing fakes.
#import "FirebaseRemoteConfig_Unit_unit-Swift.h"

@import FirebaseRemoteConfig;
@import FirebaseCore;
@import FirebaseABTesting;

typedef void (^FIRRemoteConfigFetchAndActivateCompletion)(
    FIRRemoteConfigFetchAndActivateStatus status, NSError *_Nullable error);
typedef void (^FIRRemoteConfigActivateCompletion)(NSError *_Nullable error);
typedef void (^FIRRemoteConfigFetchCompletion)(FIRRemoteConfigFetchStatus status,
                                               NSError *_Nullable error);

/// Constants for key names in the fetch response.
/// Key that includes an array of template entries.
static NSString *const RCNFetchResponseKeyEntries = @"entries";
/// Key that includes data for experiment descriptions in ABT.
static NSString *const RCNFetchResponseKeyExperimentDescriptions = @"experimentDescriptions";
/// Key that includes data for Personalization metadata.
static NSString *const RCNFetchResponseKeyPersonalizationMetadata = @"personalizationMetadata";
/// Key that includes data for Rollout metadata.
static NSString *const RCNFetchResponseKeyRolloutMetadata = @"rolloutMetadata";
/// Key that indicates rollout id in Rollout metadata.
static NSString *const RCNFetchResponseKeyRolloutID = @"rolloutId";
/// Key that indicates variant id in Rollout metadata.
static NSString *const RCNFetchResponseKeyVariantID = @"variantId";
/// Key that indicates affected parameter keys in Rollout Metadata.
static NSString *const RCNFetchResponseKeyAffectedParameterKeys = @"affectedParameterKeys";
/// Error key.
/// Error key.
static NSString *const RCNFetchResponseKeyError = @"error";
/// Error code.
static NSString *const RCNFetchResponseKeyErrorCode = @"code";
/// Error status.
static NSString *const RCNFetchResponseKeyErrorStatus = @"status";
/// Error message.
static NSString *const RCNFetchResponseKeyErrorMessage = @"message";
/// The current state of the backend template.
static NSString *const RCNFetchResponseKeyState = @"state";
/// Default state (when not set).
static NSString *const RCNFetchResponseKeyStateUnspecified = @"INSTANCE_STATE_UNSPECIFIED";
static NSString *const RCNFetchResponseKeyStateUpdate = @"UPDATE";
/// No template fetched.
static NSString *const RCNFetchResponseKeyStateNoTemplate = @"NO_TEMPLATE";
/// Config key/value map and ABT experiment list both match last fetch.
static NSString *const RCNFetchResponseKeyStateNoChange = @"NO_CHANGE";
/// Template found, but evaluates to empty (e.g. all keys omitted).
static NSString *const RCNFetchResponseKeyStateEmptyConfig = @"EMPTY_CONFIG";
/// Fetched Template Version key
static NSString *const RCNFetchResponseKeyTemplateVersion = @"templateVersion";
/// Active Template Version key
static NSString *const RCNActiveKeyTemplateVersion = @"activeTemplateVersion";

#import "FirebaseRemoteConfig/Sources/Public/FirebaseRemoteConfig/FIRRemoteConfig.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

#import <GoogleUtilities/GULNSData+zlib.h>
#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
@import FirebaseRemoteConfigInterop;

@protocol FIRRolloutsStateSubscriber;

@interface RCNMockURLSessionDataTask : NSObject <RCNURLSessionDataTaskProtocol>
@end

@implementation RCNMockURLSessionDataTask
- (void)resume {
  // Do nothing.
}
@end

@interface RCNMockConfigFetchSession : NSObject <RCNConfigFetchSession>
@property(readonly) NSURLSessionConfiguration *configuration;
@property(readonly) NSData *_Nullable data;
@property(readonly) NSURLResponse *_Nullable response;
@property(readonly) NSError *_Nullable error;
- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration
                                 data:(NSData *_Nullable)data
                             response:(NSURLResponse *_Nullable)response
                                error:(NSError *_Nullable)error;
@end

@implementation RCNMockConfigFetchSession
- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration
                                 data:(NSData *_Nullable)data
                             response:(NSURLResponse *_Nullable)response
                                error:(NSError *_Nullable)error {
  self = [super init];
  if (self) {
    _configuration = configuration;
    _data = [data copy];
    _response = [response copy];
    _error = [error copy];
  }
  return self;
}

- (id<RCNURLSessionDataTaskProtocol> _Nonnull)
         dataTaskWith:(NSURLRequest *_Nonnull)request
    completionHandler:(void (^_Nonnull)(NSData *_Nullable,
                                        NSURLResponse *_Nullable,
                                        NSError *_Nullable))completionHandler {
  completionHandler(_data, _response, _error);
  return [[RCNMockURLSessionDataTask alloc] init];
}

- (void)invalidateAndCancel {
  // Do nothing.
}
@end

@interface FIRMockInstallations : NSObject <FIRInstallationsProtocol>
@end

@implementation FIRMockInstallations
- (void)authTokenWithCompletion:(void (^_Nonnull)(FIRInstallationsAuthTokenResult *_Nullable,
                                                  NSError *_Nullable))completion {
  completion(nil, nil);
}

- (void)installationIDWithCompletion:(void (^_Nonnull)(NSString *_Nullable,
                                                       NSError *_Nullable))completion {
  completion(@"fake_installation_id", nil);
}
@end

@interface RCNConfigFetch (ForTest)
- (instancetype)initWithContent:(RCNConfigContent *)content
                      DBManager:(RCNConfigDBManager *)DBManager
                       settings:(RCNConfigSettings *)settings
                     experiment:(RCNConfigExperiment *)experiment
                          queue:(dispatch_queue_t)queue
                      namespace:firebaseNamespace
                            app:firebaseApp;
/// Skip fetching user properties from analytics because we cannot mock the action here. Instead
/// overriding the method to skip.
- (void)fetchWithUserPropertiesCompletionHandler:(NSString *)fetchTypeHeader
                               completionHandler:(FIRAInteropUserPropertiesCallback)block;
- (NSURLSessionDataTask *)URLSessionDataTaskWithContent:(NSData *)content
                                        fetchTypeHeader:(NSString *)fetchTypeHeader
                                      completionHandler:(void (^)(NSData *data,
                                                                  NSURLResponse *response,
                                                                  NSError *error))fetcherCompletion;
- (void)fetchConfigWithExpirationDuration:(NSTimeInterval)expirationDuration
                        completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler;
- (void)realtimeFetchConfigWithNoExpirationDuration:(NSInteger)fetchAttemptNumber
                                  completionHandler:(void (^)(FIRRemoteConfigFetchStatus status,
                                                              FIRRemoteConfigUpdate *update,
                                                              NSError *error))completionHandler;
- (void)fetchWithUserProperties:(NSDictionary *)userProperties
                fetchTypeHeader:(NSString *)fetchTypeHeader
              completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler
        updateCompletionHandler:(void (^)(FIRRemoteConfigFetchStatus status,
                                          FIRRemoteConfigUpdate *update,
                                          NSError *error))updateCompletionHandler;
- (NSString *)constructServerURL;
- (NSURLSession *)currentNetworkSession;
@end
//
//@interface RCNConfigRealtime (ForTest)
//
//- (instancetype _Nonnull)init:(RCNConfigFetch *_Nonnull)configFetch
//                     settings:(RCNConfigSettings *_Nonnull)settings
//                    namespace:(NSString *_Nonnull)namespace
//                      options:(FIROptions *_Nonnull)options;
//
//- (void)fetchLatestConfig:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion;
//- (void)scheduleFetch:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion;
//- (void)autoFetch:(NSInteger)remainingAttempts targetVersion:(NSInteger)targetVersion;
//- (void)beginRealtimeStream;
//- (void)pauseRealtimeStream;
//- (void)createRequestBodyWithCompletion:(void (^)(NSData *_Nonnull requestBody))completion;
//- (void)evaluateStreamResponse:(NSDictionary *)response error:(NSError *)dataError;
//
//@end

@interface FIRRemoteConfig (ForTest)
- (void)updateWithNewInstancesForConfigFetch:(RCNConfigFetch *)configFetch
                               configContent:(RCNConfigContent *)configContent
                              configSettings:(RCNConfigSettings *)configSettings
                            configExperiment:(RCNConfigExperiment *)configExperiment;

- (void)updateWithNewInstancesForConfigRealtime:(RCNConfigRealtime *)configRealtime;
@end

@implementation FIRRemoteConfig (ForTest)
- (void)updateWithNewInstancesForConfigFetch:(RCNConfigFetch *)configFetch
                               configContent:(RCNConfigContent *)configContent
                              configSettings:(RCNConfigSettings *)configSettings
                            configExperiment:(RCNConfigExperiment *)configExperiment {
  //  [self setValue:configFetch forKey:@"_configFetch"];
  //  [self setValue:configContent forKey:@"_configContent"];
  //  [self setValue:configSettings forKey:@"_settings"];
  //  [self setValue:configExperiment forKey:@"_configExperiment"];
}

- (void)updateWithNewInstancesForConfigRealtime:(RCNConfigRealtime *)configRealtime {
  //  [self setValue:configRealtime forKey:@"_configRealtime"];
}
@end

@interface RCNUserDefaultsManager (Test)
+ (NSUserDefaults *)sharedUserDefaultsForBundleIdentifier:(NSString *)bundleIdentifier;
@end

@interface RCNConfigSettings (Test)
- (NSString *)nextRequestWithUserProperties:(NSDictionary *)userProperties;
@end

typedef NS_ENUM(NSInteger, RCNTestRCInstance) {
  RCNTestRCInstanceDefault,
  RCNTestRCInstanceSecondNamespace,
  RCNTestRCInstanceSecondApp,
  RCNTestRCNumTotalInstances
};

@interface RCNRemoteConfigTest : XCTestCase {
  NSTimeInterval _expectationTimeout;
  NSTimeInterval _checkCompletionTimeout;
  NSMutableArray<FIRRemoteConfig *> *_configInstances;
  NSMutableArray<NSDictionary<NSString *, NSString *> *> *_entries;
  NSArray<NSDictionary *> *_rolloutMetadata;
  NSMutableArray<NSDictionary<NSString *, id> *> *_response;
  NSMutableArray<NSData *> *_responseData;
  NSMutableArray<NSURLResponse *> *_URLResponse;
  NSMutableArray<id> *_configFetch;
  NSMutableArray<id> *_configRealtime;
  RCNConfigDBManager *_DBManager;
  NSUserDefaults *_userDefaults;
  RCNUserDefaultsManager *_userDefaultsManager;
  NSString *_userDefaultsSuiteName;
  NSString *_DBPath;
  id _experimentMock;
  NSString *_fullyQualifiedNamespace;
  RCNConfigSettings *_settings;
  dispatch_queue_t _queue;
  NSString *_namespaceGoogleMobilePlatform;
}
@end

@implementation RCNRemoteConfigTest
- (void)setUp {
  [super setUp];
  FIRSetLoggerLevel(FIRLoggerLevelMax);

  _expectationTimeout = 5;
  _checkCompletionTimeout = 1.0;

  // Always remove the database at the start of testing.
  _DBPath = [RCNTestUtilities remoteConfigPathForTestDatabase];
  _DBManager = [[RCNConfigDBManager alloc] initWithDbPath:_DBPath];

  _userDefaultsSuiteName = [RCNTestUtilities userDefaultsSuiteNameForTestSuite];
  _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:_userDefaultsSuiteName];

  _experimentMock =
      [[RCNConfigExperimentFake alloc] initWithDbManager:_DBManager
                                    experimentController:[FIRExperimentController sharedInstance]];

  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:_DBManager];
  _configInstances = [[NSMutableArray alloc] initWithCapacity:3];
  _entries = [[NSMutableArray alloc] initWithCapacity:3];
  _response = [[NSMutableArray alloc] initWithCapacity:3];
  _responseData = [[NSMutableArray alloc] initWithCapacity:3];
  _URLResponse = [[NSMutableArray alloc] initWithCapacity:3];
  _configFetch = [[NSMutableArray alloc] initWithCapacity:3];
  _configRealtime = [[NSMutableArray alloc] initWithCapacity:3];
  _namespaceGoogleMobilePlatform = FIRRemoteConfigConstants.FIRNamespaceGoogleMobilePlatform;

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
        currentNamespace = _namespaceGoogleMobilePlatform;
        break;
      case RCNTestRCInstanceDefault:
      default:
        currentAppName = RCNTestsDefaultFIRAppName;
        currentOptions = [self firstAppOptions];
        currentNamespace = RCNTestsFIRNamespace;
        break;
    }
    _fullyQualifiedNamespace =
        [NSString stringWithFormat:@"%@:%@", currentNamespace, currentAppName];

    _rolloutMetadata = @[ @{
      RCNFetchResponseKeyRolloutID : @"1",
      RCNFetchResponseKeyVariantID : @"0",
      RCNFetchResponseKeyAffectedParameterKeys : @[ _entries[i].allKeys[0] ]
    } ];

    _response[i] = @{
      @"state" : @"UPDATE",
      @"entries" : _entries[i],
      RCNFetchResponseKeyRolloutMetadata : _rolloutMetadata
    };

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    _URLResponse[i] = [[NSHTTPURLResponse alloc]
         initWithURL:[NSURL URLWithString:@"https://firebase.com"]
          statusCode:200
         HTTPVersion:nil
        headerFields:@{@"etag" : [NSString stringWithFormat:@"etag1-%d", i]}];

    _settings = [[RCNConfigSettings alloc] initWithDatabaseManager:_DBManager
                                                         namespace:_fullyQualifiedNamespace
                                                   firebaseAppName:currentAppName
                                                       googleAppID:currentOptions.googleAppID
                                                      userDefaults:_userDefaults];
    _queue = dispatch_queue_create(
        [[NSString stringWithFormat:@"testqueue: %d", i] cStringUsingEncoding:NSUTF8StringEncoding],
        DISPATCH_QUEUE_SERIAL);

    RCNConfigFetch *configFetch = [[RCNConfigFetch alloc]
             initWithContent:configContent
                   DBManager:_DBManager
                    settings:_settings
                   analytics:nil
                  experiment:_experimentMock
                       queue:_queue
                   namespace:_fullyQualifiedNamespace
                     options:currentOptions
        fetchSessionProvider:^id<RCNConfigFetchSession> _Nonnull(
            NSURLSessionConfiguration *_Nonnull config) {
          return [[RCNMockConfigFetchSession alloc] initWithConfiguration:config
                                                                     data:self->_responseData[i]
                                                                 response:self->_URLResponse[i]
                                                                    error:nil];
        }
               installations:[[FIRMockInstallations alloc] init]];
    _configRealtime[i] =
        [[RCNConfigRealtime alloc] initWithConfigFetch:configFetch
                                              settings:_settings
                                             namespace:_fullyQualifiedNamespace
                                               options:currentOptions
                                         installations:[[FIRMockInstallations alloc] init]];
    FIRRemoteConfig *config = [[FIRRemoteConfig alloc] initWithAppName:currentAppName
                                                            FIROptions:currentOptions
                                                             namespace:currentNamespace
                                                             DBManager:_DBManager
                                                         configContent:configContent
                                                          userDefaults:_userDefaults
                                                             analytics:nil
                                                           configFetch:configFetch
                                                        configRealtime:_configRealtime[i]
                                                              settings:_settings];
    _configFetch[i] = configFetch;
    _configInstances[i] = config;
    _settings.configInstallationsIdentifier = @"iid";

    // TODO: Consider deleting rest of function...
    //    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
    //                                                configContent:configContent
    //                                               configSettings:_settings
    //                                             configExperiment:_experimentMock];
    //    [_configInstances[i] updateWithNewInstancesForConfigRealtime:_configRealtime[i]];
  }
}

- (void)tearDown {
  [_DBManager removeDatabaseWithPath:_DBPath];
  [FIRRemoteConfigComponent clearAllComponentInstances];
  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:_userDefaultsSuiteName];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    //    [(id)_configFetch[i] stopMocking];
  }
  [_configInstances removeAllObjects];
  [_configFetch removeAllObjects];
  [_configRealtime removeAllObjects];
  _configInstances = nil;
  _configFetch = nil;
  [super tearDown];
}

- (void)testFetchConfigWithNilCallback {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Set defaults no callback expectation - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);

    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:nil];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          XCTAssertEqual(self->_configInstances[i].lastFetchStatus,
                         FIRRemoteConfigFetchStatusSuccess);
          [expectations[i] fulfill];
        });
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}
#ifdef DEFER_ACTIVATE
- (void)testFetchConfigsSuccessfully {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    __auto_type fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                        NSError *_Nullable error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
        NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
        NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
        NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];
        XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
        XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);

        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccessFresh.");

        XCTAssertNotNil(self->_configInstances[i].lastFetchTime);
        XCTAssertGreaterThan(self->_configInstances[i].lastFetchTime.timeIntervalSince1970, 0,
                             @"last fetch time interval should be set.");
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

- (void)testFetchAndActivate {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    FIRRemoteConfigFetchAndActivateCompletion fetchAndActivateCompletion = ^void(
        FIRRemoteConfigFetchAndActivateStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);

      NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
      NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
      NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
      NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
      XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);

      XCTAssertEqual(
          status, FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote,
          @"Callback of first successful config "
          @"fetchAndActivate status must equal to FIRRemoteConfigFetchAndStatusSuccessFromRemote.");

      XCTAssertNotNil(self->_configInstances[i].lastFetchTime);
      XCTAssertGreaterThan(self->_configInstances[i].lastFetchTime.timeIntervalSince1970, 0,
                           @"last fetch time interval should be set.");
      [expectations[i] fulfill];
    };
    // Update the minimum fetch interval to 0. This disables the cache and forces a remote fetch
    // request.
    FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
    settings.minimumFetchInterval = 0;
    [_configInstances[i] setConfigSettings:settings];
    [_configInstances[i] fetchAndActivateWithCompletionHandler:fetchAndActivateCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// TODO: Try splitting into smaller tests.
- (void)testFetchConfigsSuccessfullyWithNewActivateMethodSignature {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    FIRRemoteConfigFetchCompletion fetchCompletion = ^(FIRRemoteConfigFetchStatus status,
                                                       NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        XCTAssertNil(error);
        NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
        NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
        NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
        NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];
        XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
        XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);

        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccessFresh.");

        XCTAssertNotNil(self->_configInstances[i].lastFetchTime);
        XCTAssertGreaterThan(self->_configInstances[i].lastFetchTime.timeIntervalSince1970, 0,
                             @"last fetch time interval should be set.");

        // A second activate should have no effect.
        [self->_configInstances[i]
            activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
              XCTAssertFalse(changed);
              XCTAssertNil(error);
            }];
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

- (void)testEnumeratingConfigResults {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test enumerating configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        NSString *key5 = [NSString stringWithFormat:@"key5-%d", i];
        NSString *key19 = [NSString stringWithFormat:@"key19-%d", i];
        NSString *value5 = [NSString stringWithFormat:@"value5-%d", i];
        NSString *value19 = [NSString stringWithFormat:@"value19-%d", i];

        XCTAssertEqualObjects(self->_configInstances[i][key5].stringValue, value5);
        XCTAssertEqualObjects(self->_configInstances[i][key19].stringValue, value19);

        // Test enumerating config values.
        for (NSString *key in self->_configInstances[i]) {
          if ([key isEqualToString:key5]) {
            XCTAssertEqualObjects(self->_configInstances[i][key5].stringValue, value5);
          }
          if ([key isEqualToString:key19]) {
            XCTAssertEqualObjects(self->_configInstances[i][key19].stringValue, value19);
          }
        }
        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccessFresh.");

        XCTAssertNotNil(self->_configInstances[i].lastFetchTime);
        XCTAssertGreaterThan(self->_configInstances[i].lastFetchTime.timeIntervalSince1970, 0,
                             @"last fetch time interval should be set.");

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

- (void)testFetchAndActivate3pNamespaceUpdatesExperiments {
  //  [[_experimentMock expect] updateExperimentsWithResponse:[OCMArg any]];

  XCTestExpectation *expectation = [self
      expectationWithDescription:[NSString stringWithFormat:@"FetchAndActivate call for 'firebase' "
                                                            @"namespace updates experiment data"]];
  XCTAssertEqual(_configInstances[RCNTestRCInstanceDefault].lastFetchStatus,
                 FIRRemoteConfigFetchStatusNoFetchYet);

  FIRRemoteConfigFetchAndActivateCompletion fetchAndActivateCompletion =
      ^void(FIRRemoteConfigFetchAndActivateStatus status, NSError *error) {
        XCTAssertEqual(status, FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote);
        XCTAssertNil(error);

        XCTAssertEqual(self->_configInstances[RCNTestRCInstanceDefault].lastFetchStatus,
                       FIRRemoteConfigFetchStatusSuccess);
        XCTAssertNotNil(self->_configInstances[RCNTestRCInstanceDefault].lastFetchTime);
        XCTAssertGreaterThan(
            self->_configInstances[RCNTestRCInstanceDefault].lastFetchTime.timeIntervalSince1970, 0,
            @"last fetch time interval should be set.");
        [expectation fulfill];
      };

  [_configInstances[RCNTestRCInstanceDefault]
      fetchAndActivateWithCompletionHandler:fetchAndActivateCompletion];
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// TODO: Restore when
- (void)SKIPtestFetchAndActivateOtherNamespaceDoesntUpdateExperiments {
  [[_experimentMock reject] updateExperimentsWithResponse:[OCMArg any]];

  XCTestExpectation *expectation = [self
      expectationWithDescription:
          [NSString stringWithFormat:@"FetchAndActivate call for namespace other than 'firebase' "
                                     @"doesn't update experiment data"]];
  XCTAssertEqual(_configInstances[RCNTestRCInstanceSecondNamespace].lastFetchStatus,
                 FIRRemoteConfigFetchStatusNoFetchYet);

  FIRRemoteConfigFetchAndActivateCompletion fetchAndActivateCompletion =
      ^void(FIRRemoteConfigFetchAndActivateStatus status, NSError *error) {
        XCTAssertEqual(status, FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote);
        XCTAssertNil(error);

        XCTAssertEqual(self->_configInstances[RCNTestRCInstanceSecondNamespace].lastFetchStatus,
                       FIRRemoteConfigFetchStatusSuccess);
        XCTAssertNotNil(self->_configInstances[RCNTestRCInstanceSecondNamespace].lastFetchTime);
        XCTAssertGreaterThan(self->_configInstances[RCNTestRCInstanceSecondNamespace]
                                 .lastFetchTime.timeIntervalSince1970,
                             0, @"last fetch time interval should be set.");
        [expectation fulfill];
      };

  [_configInstances[RCNTestRCInstanceSecondNamespace]
      fetchAndActivateWithCompletionHandler:fetchAndActivateCompletion];
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testFetchConfigsFailed {
  // Override the setup values to return back an error status.
  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:_DBManager];
  // Populate the default, second app, second namespace instances.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
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
        currentNamespace = _namespaceGoogleMobilePlatform;
        break;
      case RCNTestRCInstanceDefault:
      default:
        currentAppName = RCNTestsDefaultFIRAppName;
        currentOptions = [self firstAppOptions];
        currentNamespace = RCNTestsFIRNamespace;
        break;
    }

    FIRRemoteConfig *config = [[FIRRemoteConfig alloc] initWithAppName:currentAppName
                                                            FIROptions:currentOptions
                                                             namespace:currentNamespace
                                                             DBManager:_DBManager
                                                         configContent:configContent
                                                          userDefaults:_userDefaults
                                                             analytics:nil
                                                           configFetch:nil
                                                        configRealtime:nil
                                                              settings:nil];

    _configInstances[i] = config;

    _response[i] = @{};

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    _URLResponse[i] =
        [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://firebase.com"]
                                    statusCode:500
                                   HTTPVersion:nil
                                  headerFields:@{@"etag" : @"etag1"}];

    _configFetch[i] = [[RCNConfigFetch alloc] initWithContent:configContent
                                                    DBManager:_DBManager
                                                     settings:config.settings
                                                    analytics:nil
                                                   experiment:nil
                                                        queue:_queue
                                                    namespace:currentNamespace
                                                      options:currentOptions
                                         fetchSessionProvider:^id<RCNConfigFetchSession> _Nonnull(
                                             NSURLSessionConfiguration *_Nonnull config) {
                                           return [[RCNMockConfigFetchSession alloc]
                                               initWithConfiguration:config
                                                                data:self->_responseData[i]
                                                            response:self->_URLResponse[i]
                                                               error:nil];
                                         }
                                                installations:[[FIRMockInstallations alloc] init]];

    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
                                                configContent:configContent
                                               configSettings:config.settings
                                             configExperiment:nil];
  }
  // Make the fetch calls for all instances.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    XCTestExpectation *expectation = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test enumerating configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    __auto_type fetchCompletion = ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusFailure);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertFalse(changed);
        XCTAssertNil(error);
        FIRRemoteConfigValue *value = self->_configInstances[RCNTestRCInstanceDefault][@"key1"];
        XCTAssertEqual((int)value.source, (int)FIRRemoteConfigSourceStatic);
        XCTAssertEqualObjects(value.stringValue, @"");
        XCTAssertEqual(value.boolValue, NO);
        [expectation fulfill];
      }];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
    [self waitForExpectations:@[ expectation ] timeout:_expectationTimeout];
  }
}

// TODO(mandard): Break up test with helper methods.
- (void)testFetchConfigsFailedErrorNoNetwork {
  // Override the setup values to return back an error status.
  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:_DBManager];
  // Populate the default, second app, second namespace instances.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
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
        currentNamespace = _namespaceGoogleMobilePlatform;
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
    RCNUserDefaultsManager *userDefaultsManager =
        [[RCNUserDefaultsManager alloc] initWithAppName:currentAppName
                                               bundleID:[NSBundle mainBundle].bundleIdentifier
                                              namespace:fullyQualifiedNamespace
                                           userDefaults:_userDefaults];
    userDefaultsManager.lastFetchTime = 0;

    FIRRemoteConfig *config =
        OCMPartialMock([[FIRRemoteConfig alloc] initWithAppName:currentAppName
                                                     FIROptions:currentOptions
                                                      namespace:currentNamespace
                                                      DBManager:_DBManager
                                                  configContent:configContent
                                                   userDefaults:_userDefaults
                                                      analytics:nil
                                                    configFetch:nil
                                                 configRealtime:nil
                                                       settings:nil]);

    _configInstances[i] = config;
    RCNConfigSettings *settings =
        [[RCNConfigSettings alloc] initWithDatabaseManager:_DBManager
                                                 namespace:fullyQualifiedNamespace
                                           firebaseAppName:currentAppName
                                               googleAppID:currentOptions.googleAppID
                                              userDefaults:_userDefaults];
    dispatch_queue_t queue = dispatch_queue_create(
        [[NSString stringWithFormat:@"testqueue: %d", i] cStringUsingEncoding:NSUTF8StringEncoding],
        DISPATCH_QUEUE_SERIAL);

    _response[i] = @{};

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    // A no network error is accompanied with an HTTP status code of 0.
    _URLResponse[i] =
        [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://firebase.com"]
                                    statusCode:0
                                   HTTPVersion:nil
                                  headerFields:@{@"etag" : @"etag1"}];

    _configFetch[i] = [[RCNConfigFetch alloc] initWithContent:configContent
                                                    DBManager:_DBManager
                                                     settings:settings
                                                    analytics:nil
                                                   experiment:nil
                                                        queue:queue
                                                    namespace:fullyQualifiedNamespace
                                                      options:currentOptions
                                         fetchSessionProvider:^id<RCNConfigFetchSession> _Nonnull(
                                             NSURLSessionConfiguration *_Nonnull config) {
                                           return [[RCNMockConfigFetchSession alloc]
                                               initWithConfiguration:config
                                                                data:self->_responseData[i]
                                                            response:self->_URLResponse[i]
                                                               error:nil];
                                         }
                                                installations:[[FIRMockInstallations alloc] init]];

    _configRealtime[i] =
        [[RCNConfigRealtime alloc] initWithConfigFetch:_configFetch[i]
                                              settings:settings
                                             namespace:fullyQualifiedNamespace
                                               options:currentOptions
                                         installations:[[FIRMockInstallations alloc] init]];

    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
                                                configContent:configContent
                                               configSettings:settings
                                             configExperiment:nil];
  }
  // Make the fetch calls for all instances.
  for (int i = 0; i < RCNTestRCNumTotalInstances - 2; i++) {
    XCTestExpectation *expectation = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test enumerating configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusFailure);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertFalse(changed);
        XCTAssertNil(error);
        // No such key, still return a static value.
        FIRRemoteConfigValue *value = self->_configInstances[RCNTestRCInstanceDefault][@"key1"];
        XCTAssertEqual((int)value.source, (int)FIRRemoteConfigSourceStatic);
        XCTAssertEqualObjects(value.stringValue, @"");
        XCTAssertEqual(value.boolValue, NO);
        [expectation fulfill];
      }];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
    [self waitForExpectations:@[ expectation ] timeout:_expectationTimeout];
  }
}

- (void)testFetchFailedNoNetworkErrorDoesNotThrottle {
  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:_DBManager];
  NSString *currentAppName = RCNTestsDefaultFIRAppName;
  FIROptions *currentOptions = [self firstAppOptions];
  NSString *currentNamespace = RCNTestsFIRNamespace;
  NSString *fullyQualifiedNamespace =
      [NSString stringWithFormat:@"%@:%@", currentNamespace, currentAppName];

  RCNUserDefaultsManager *userDefaultsManager =
      [[RCNUserDefaultsManager alloc] initWithAppName:currentAppName
                                             bundleID:[NSBundle mainBundle].bundleIdentifier
                                            namespace:fullyQualifiedNamespace];
  userDefaultsManager.lastFetchTime = 0;

  FIRRemoteConfig *config = OCMPartialMock([[FIRRemoteConfig alloc] initWithAppName:currentAppName
                                                                         FIROptions:currentOptions
                                                                          namespace:currentNamespace
                                                                          DBManager:_DBManager
                                                                      configContent:configContent
                                                                          analytics:nil]);
  RCNConfigSettings *settings =
      [[RCNConfigSettings alloc] initWithDatabaseManager:_DBManager
                                               namespace:fullyQualifiedNamespace
                                         firebaseAppName:currentAppName
                                             googleAppID:currentOptions.googleAppID];
  dispatch_queue_t queue = dispatch_queue_create(
      [[NSString stringWithFormat:@"testqueue"] cStringUsingEncoding:NSUTF8StringEncoding],
      DISPATCH_QUEUE_SERIAL);
  _responseData[0] = [NSJSONSerialization dataWithJSONObject:@{} options:0 error:nil];

  // A no network error is accompanied with an HTTP status code of 0.
  _URLResponse[0] =
      [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://firebase.com"]
                                  statusCode:0
                                 HTTPVersion:nil
                                headerFields:@{@"etag" : @"etag1"}];

  RCNConfigFetch *configFetch = [[RCNConfigFetch alloc]
           initWithContent:configContent
                 DBManager:_DBManager
                  settings:settings
                 analytics:nil
                experiment:nil
                     queue:queue
                 namespace:fullyQualifiedNamespace
                   options:currentOptions
      fetchSessionProvider:^id<RCNConfigFetchSession> _Nonnull(
          NSURLSessionConfiguration *_Nonnull config) {
        return [[RCNMockConfigFetchSession alloc] initWithConfiguration:config
                                                                   data:self->_responseData[0]
                                                               response:self->_URLResponse[0]
                                                                  error:nil];
      }
             installations:[[FIRMockInstallations alloc] init]];

  [config updateWithNewInstancesForConfigFetch:configFetch
                                 configContent:configContent
                                configSettings:settings
                              configExperiment:nil];

  XCTestExpectation *expectation =
      [self expectationWithDescription:@"Network error doesn't increase throttle interval"];
  XCTAssertEqual(config.lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);

  FIRRemoteConfigFetchCompletion fetchCompletion =
      ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
        XCTAssertEqual(config.lastFetchStatus, FIRRemoteConfigFetchStatusFailure);
        XCTAssertEqual(settings.exponentialBackoffRetryInterval, 0);
        [expectation fulfill];
      };

  [config fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// Activate should return false if a fetch response returns 200 with NO_CHANGE as the response body.
- (void)testActivateOnFetchNoChangeStatus {
  // Override the setup values to return back an error status.
  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:_DBManager];
  // Populate the default, second app, second namespace instances.
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
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
        currentNamespace = _namespaceGoogleMobilePlatform;
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
    RCNUserDefaultsManager *userDefaultsManager =
        [[RCNUserDefaultsManager alloc] initWithAppName:currentAppName
                                               bundleID:[NSBundle mainBundle].bundleIdentifier
                                              namespace:fullyQualifiedNamespace];
    userDefaultsManager.lastFetchTime = 10;

    FIRRemoteConfig *config = [[FIRRemoteConfig alloc] initWithAppName:currentAppName
                                                            FIROptions:currentOptions
                                                             namespace:currentNamespace
                                                             DBManager:_DBManager
                                                         configContent:configContent
                                                             analytics:nil];

    _configInstances[i] = config;
    RCNConfigSettings *settings =
        [[RCNConfigSettings alloc] initWithDatabaseManager:_DBManager
                                                 namespace:fullyQualifiedNamespace
                                           firebaseAppName:currentAppName
                                               googleAppID:currentOptions.googleAppID];
    // Start the test with the assumption that we have some data that was fetched and activated.
    settings.lastETag = @"etag1";
    settings.lastETagUpdateTime = 100;
    settings.lastApplyTimeInterval = 101;

    dispatch_queue_t queue =
        dispatch_queue_create([[NSString stringWithFormat:@"testNoStatusFetchQueue: %d", i]
                                  cStringUsingEncoding:NSUTF8StringEncoding],
                              DISPATCH_QUEUE_SERIAL);
    _response[i] = @{@"state" : @"NO_CHANGE"};

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    _URLResponse[i] =
        [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://firebase.com"]
                                    statusCode:200
                                   HTTPVersion:nil
                                  headerFields:@{@"etag" : @"etag1"}];

    _configFetch[i] = [[RCNConfigFetch alloc] initWithContent:configContent
                                                    DBManager:_DBManager
                                                     settings:settings
                                                    analytics:nil
                                                   experiment:nil
                                                        queue:queue
                                                    namespace:fullyQualifiedNamespace
                                                      options:currentOptions
                                         fetchSessionProvider:^id<RCNConfigFetchSession> _Nonnull(
                                             NSURLSessionConfiguration *_Nonnull config) {
                                           return [[RCNMockConfigFetchSession alloc]
                                               initWithConfiguration:config
                                                                data:self->_responseData[i]
                                                            response:self->_URLResponse[i]
                                                               error:nil];
                                         }
                                                installations:[[FIRMockInstallations alloc] init]];

    _configRealtime[i] =
        [[RCNConfigRealtime alloc] initWithConfigFetch:_configFetch[i]
                                              settings:settings
                                             namespace:fullyQualifiedNamespace
                                               options:currentOptions
                                         installations:[[FIRMockInstallations alloc] init]];

    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
                                                configContent:configContent
                                               configSettings:settings
                                             configExperiment:nil];
  }
  // Make the fetch calls for all instances.
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test enumerating configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);

    // Make sure activate returns false in fetch completion.
    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertFalse(changed);
        XCTAssertNil(error);
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

- (void)testConfigValueForKey {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test configValueForKey: method - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
        NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
        NSString *key3 = [NSString stringWithFormat:@"key3-%d", i];
        NSString *key7 = [NSString stringWithFormat:@"key7-%d", i];
        NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
        NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];
        NSString *value3 = [NSString stringWithFormat:@"value3-%d", i];
        NSString *value7 = [NSString stringWithFormat:@"value7-%d", i];
        XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
        XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);
        XCTAssertEqualObjects([self->_configInstances[i] configValueForKey:key3].stringValue,
                              value3);
        if (i == RCNTestRCInstanceDefault) {
          XCTAssertEqualObjects([self->_configInstances[i] configValueForKey:key7].stringValue,
                                value7);
        }

        XCTAssertEqualObjects([self->_configInstances[i] configValueForKey:key7].stringValue,
                              value7);
        XCTAssertNotNil([self->_configInstances[i] configValueForKey:nil]);
        XCTAssertEqual([self->_configInstances[i] configValueForKey:nil].source,
                       FIRRemoteConfigSourceStatic);
        XCTAssertEqual([self->_configInstances[i] configValueForKey:nil].source,
                       FIRRemoteConfigSourceStatic);
        XCTAssertEqual([self->_configInstances[i] configValueForKey:nil source:-1].source,
                       FIRRemoteConfigSourceStatic);

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

- (void)testFetchConfigWithDefaultSets {
  NSMutableArray<XCTestExpectation *> *fetchConfigsExpectation =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    fetchConfigsExpectation[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test fetch configs with defaults set - instance %d", i]];
    NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
    NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
    NSString *key0 = [NSString stringWithFormat:@"key0-%d", i];
    NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
    NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];

    NSDictionary<NSString *, NSString *> *defaults = @{key1 : @"default key1", key0 : @"value0-0"};
    [_configInstances[i] setDefaults:defaults];

    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, @"default key1");
      XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceDefault);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
        XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceRemote);
        XCTAssertEqualObjects([self->_configInstances[i] defaultValueForKey:key1].stringValue,
                              @"default key1");
        XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);
        XCTAssertEqualObjects(self->_configInstances[i][key0].stringValue, @"value0-0");
        XCTAssertNil([self->_configInstances[i] defaultValueForKey:nil]);
        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccess.");
        [fetchConfigsExpectation[i] fulfill];
      }];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}
#endif
- (void)testDefaultsSetsOnly {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
    NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
    NSString *key3 = [NSString stringWithFormat:@"key3-%d", i];
    NSString *key4 = [NSString stringWithFormat:@"key4-%d", i];
    NSString *key5 = [NSString stringWithFormat:@"key5-%d", i];

    NSString *defaultValue1 = @"default value1";
    NSData *defaultValue2 = [defaultValue1 dataUsingEncoding:NSUTF8StringEncoding];
    NSNumber *defaultValue3 = [NSNumber numberWithFloat:3.1415926];
    NSDate *defaultValue4 = [NSDate date];
    BOOL defaultValue5 = NO;

    NSMutableDictionary<NSString *, id> *defaults = [NSMutableDictionary dictionaryWithDictionary:@{
      key1 : defaultValue1,
      key2 : defaultValue2,
      key3 : defaultValue3,
      key4 : defaultValue4,
      key5 : @(defaultValue5),
    }];
    [_configInstances[i] setDefaults:defaults];
    if (i == RCNTestRCInstanceSecondNamespace) {
      [defaults setObject:@"2860" forKey:@"experience"];
      [_configInstances[i] setDefaults:defaults];
    }
    // Remove objects right away to make sure dispatch_async gets the copy.
    [defaults removeAllObjects];

    FIRRemoteConfig *config = _configInstances[i];
    XCTAssertEqualObjects(config[key1].stringValue, defaultValue1, @"Should support string format");
    XCTAssertEqualObjects(config[key2].dataValue, defaultValue2, @"Should support data format");
    XCTAssertEqual(config[key3].numberValue.longValue, defaultValue3.longValue,
                   @"Should support number format");

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    NSString *strValueOfDate = [dateFormatter stringFromDate:(NSDate *)defaultValue4];
    XCTAssertEqualObjects(
        config[key4].stringValue, strValueOfDate,
        @"Date format can be set as an input from plist, but output coming out of "
        @"defaultConfig as string.");

    XCTAssertEqual(config[key5].boolValue, defaultValue5, @"Should support bool format");

    if (i == RCNTestRCInstanceSecondNamespace) {
      XCTAssertEqualObjects(
          [_configInstances[i] configValueForKey:@"experience"].stringValue, @"2860",
          @"Only default config has the key, must equal to default config value.");
    }

    // Reset default sets
    [_configInstances[i] setDefaults:nil];
    XCTAssertEqual([_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault].count, 0);
  }
}

- (void)testSetDefaultsWithNilParams {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Set defaults no callback expectation - instance %d", i]];
    // Should work when passing nil.
    [_configInstances[i] setDefaults:nil];
    [_configInstances[i] setDefaults:nil];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          XCTAssertEqual(
              [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault].count, 0);
          [expectations[i] fulfill];
        });
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}

#ifdef LATER
- (void)testFetchConfigOverwriteDefaultSet {
  NSMutableArray<XCTestExpectation *> *fetchConfigsExpectation =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    fetchConfigsExpectation[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test fetch configs with defaults set - instance %d", i]];
    NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
    NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];

    [_configInstances[i] setDefaults:@{key1 : @"default key1"}];

    FIRRemoteConfigValue *value = _configInstances[i][key1];
    XCTAssertEqualObjects(value.stringValue, @"default key1");
    XCTAssertEqual(value.source, FIRRemoteConfigSourceDefault);

    value = _configInstances[i][@"A key doesn't exist"];
    XCTAssertEqual(value.source, FIRRemoteConfigSourceStatic);

    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);

      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
        XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceRemote);
        XCTAssertEqualObjects([self->_configInstances[i] defaultValueForKey:key1].stringValue,
                              @"default key1");

        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccess.");
        [fetchConfigsExpectation[i] fulfill];
      }];
    };

    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testGetConfigValueBySource {
  NSMutableArray<XCTestExpectation *> *fetchConfigsExpectation =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    fetchConfigsExpectation[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test get config value by source - instance %d", i]];
    NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
    NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];

    NSDictionary<NSString *, NSString *> *defaults = @{key1 : @"default value1"};
    [_configInstances[i] setDefaults:defaults];

    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, @"default value1");
      XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceDefault);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
        XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceRemote);
        FIRRemoteConfigValue *value;
        if (i == RCNTestRCInstanceDefault) {
          value = [self->_configInstances[i] configValueForKey:key1
                                                        source:FIRRemoteConfigSourceRemote];
          XCTAssertEqualObjects(value.stringValue, value1);
          value = [self->_configInstances[i] configValueForKey:key1
                                                        source:FIRRemoteConfigSourceDefault];
          XCTAssertEqualObjects(value.stringValue, @"default value1");
          value = [self->_configInstances[i] configValueForKey:key1
                                                        source:FIRRemoteConfigSourceStatic];
        } else {
          value = [self->_configInstances[i] configValueForKey:key1
                                                        source:FIRRemoteConfigSourceRemote];
          XCTAssertEqualObjects(value.stringValue, value1);
          value = [self->_configInstances[i] configValueForKey:key1
                                                        source:FIRRemoteConfigSourceDefault];
          XCTAssertEqualObjects(value.stringValue, @"default value1");
          value = [self->_configInstances[i] configValueForKey:key1
                                                        source:FIRRemoteConfigSourceStatic];
        }
        XCTAssertEqualObjects(value.stringValue, @"");
        XCTAssertEqualObjects(value.numberValue, @(0));
        XCTAssertEqual(value.boolValue, NO);

        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccess.");
        [fetchConfigsExpectation[i] fulfill];
      }];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}
#endif

- (void)testInvalidKeyOrNamespace {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    FIRRemoteConfigValue *value = [_configInstances[i] configValueForKey:nil];
    XCTAssertNotNil(value);
    XCTAssertEqual(value.source, FIRRemoteConfigSourceStatic);

    value = [_configInstances[i] configValueForKey:nil];
    XCTAssertNotNil(value);
    XCTAssertEqual(value.source, FIRRemoteConfigSourceStatic);

    value = [_configInstances[i] configValueForKey:nil source:5];
    XCTAssertNotNil(value);
    XCTAssertEqual(value.source, FIRRemoteConfigSourceStatic);
  }
}

// Remote Config converts UTC times in the plists to local times. This utility function makes it
// possible to check the times when running the tests in any timezone.
static NSString *UTCToLocal(NSString *utcTime) {
  // Create a UTC dateFormatter.
  NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
  [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
  [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
  NSDate *date = [dateFormatter dateFromString:utcTime];
  [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
  return [dateFormatter stringFromDate:date];
}

// Manage different bundle locations for Swift Package Manager, CocoaPods static, CocoaPods dynamic.
- (void)setDefaultsFor:(FIRRemoteConfig *)config {
#if SWIFT_PACKAGE
  NSBundle *bundle = SWIFTPM_MODULE_BUNDLE;
  NSString *plistFile = [bundle pathForResource:@"Defaults-testInfo" ofType:@"plist"];
#else
  NSBundle *bundle = [NSBundle mainBundle];
  NSString *plistFile = [bundle pathForResource:@"Defaults-testInfo" ofType:@"plist"];
  if (plistFile != nil) {
    [config setDefaultsFromPlistFileName:@"Defaults-testInfo"];
    return;
  }
  // We've linked dynamically and the plist file is in the test's bundle.
  for (bundle in [NSBundle allBundles]) {
    plistFile = [bundle pathForResource:@"Defaults-testInfo" ofType:@"plist"];
    if (plistFile != nil) {
      break;
    }
  }
#endif
  NSDictionary *defaults = [[NSDictionary alloc] initWithContentsOfFile:plistFile];
  [config setDefaults:defaults];
}

- (void)testSetDefaultsFromPlist {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    FIRRemoteConfig *config = _configInstances[i];
    [self setDefaultsFor:config];
    XCTAssertEqualObjects(_configInstances[i][@"lastCheckTime"].stringValue,
                          UTCToLocal(@"2016-02-28 18:33:31"));
    XCTAssertEqual(_configInstances[i][@"isPaidUser"].boolValue, YES);
    XCTAssertEqualObjects(_configInstances[i][@"dataValue"].stringValue, @"2.4");
    XCTAssertEqualObjects(_configInstances[i][@"New item"].numberValue, @(2.4));
    XCTAssertEqualObjects(_configInstances[i][@"Languages"].stringValue, @"English");
    XCTAssertEqualObjects(_configInstances[i][@"FileInfo"].stringValue,
                          @"To setup default config.");
    XCTAssertEqualObjects(_configInstances[i][@"format"].stringValue, @"key to value.");
    XCTAssertEqualObjects(_configInstances[i][@"arrayValue"].JSONValue,
                          ((id) @[ @"foo", @"bar", @"baz" ]));
    XCTAssertEqualObjects(_configInstances[i][@"dictValue"].JSONValue,
                          ((id) @{@"foo" : @"foo", @"bar" : @"bar", @"baz" : @"baz"}));

    // If given a wrong file name, the default will not be set and kept as previous results.
    [_configInstances[i] setDefaultsFromPlistFileName:@""];
    XCTAssertEqualObjects(_configInstances[i][@"lastCheckTime"].stringValue,
                          UTCToLocal(@"2016-02-28 18:33:31"));
    [_configInstances[i] setDefaultsFromPlistFileName:@"non-existed_file"];
    XCTAssertEqualObjects(_configInstances[i][@"dataValue"].stringValue, @"2.4");
    [_configInstances[i] setDefaultsFromPlistFileName:nil];
    XCTAssertEqualObjects(_configInstances[i][@"New item"].numberValue, @(2.4));
    [_configInstances[i] setDefaultsFromPlistFileName:@""];
    XCTAssertEqualObjects(_configInstances[i][@"Languages"].stringValue, @"English");
  }
}

#ifdef DEFER_ACTIVATE
- (void)testAllKeysFromSource {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    XCTestExpectation *expectation = [self
        expectationWithDescription:[NSString
                                       stringWithFormat:@"Test allKeys methods - instance %d", i]];
    NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
    NSString *key0 = [NSString stringWithFormat:@"key0-%d", i];
    NSDictionary<NSString *, NSString *> *defaults = @{key1 : @"default key1", key0 : @"value0-0"};
    [_configInstances[i] setDefaults:defaults];

    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceRemote].count, 100);
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault].count, 2);
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceStatic].count, 0);

        [expectation fulfill];
      }];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
    [self waitForExpectations:@[ expectation ] timeout:15.0 /*_expectationTimeout*/];
  }
}

- (void)testAllKeysWithPrefix {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    XCTestExpectation *expectation = [self
        expectationWithDescription:[NSString
                                       stringWithFormat:@"Test allKeys methods - instance %d", i]];
    FIRRemoteConfigFetchCompletion fetchCompletion = ^void(FIRRemoteConfigFetchStatus status,
                                                           NSError *error) {
      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      NSLog(@"Testing _configInstances %d", i);
      [self->_configInstances[i] activateWithCompletion:^(BOOL changed, NSError *_Nullable error) {
        XCTAssertTrue(changed);
        // Test keysWithPrefix: method.
        XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"key1"].count, 12);
        XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"key"].count, 100);

        XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"invalid key"].count, 0);
        XCTAssertEqual([self->_configInstances[i] keysWithPrefix:nil].count, 100);
        XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@""].count, 100);

        [expectation fulfill];
      }];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
    [self waitForExpectations:@[ expectation ] timeout:_expectationTimeout];
  }
}
#endif
/// Test the minimum fetch interval is applied and read back correctly.
- (void)testSetMinimumFetchIntervalConfigSetting {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    XCTestExpectation *expectation = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test minimumFetchInterval expectation - instance %d", i]];
    FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
    settings.minimumFetchInterval = 123;
    [_configInstances[i] setConfigSettings:settings];
    XCTAssertEqual([_configInstances[i] configSettings].minimumFetchInterval, 123);

    FIRRemoteConfigFetchCompletion fetchCompletion =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertFalse([self->_configInstances[i].settings hasMinimumFetchIntervalElapsed:43200]);

          // Update minimum fetch interval.
          FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
          settings.minimumFetchInterval = 0;
          [self->_configInstances[i] setConfigSettings:settings];
          XCTAssertEqual([self->_configInstances[i] configSettings].minimumFetchInterval, 0);
          XCTAssertTrue([self->_configInstances[i].settings hasMinimumFetchIntervalElapsed:0]);
          [expectation fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
    [self waitForExpectations:@[ expectation ] timeout:_expectationTimeout];
  }
}

/// Test the fetch timeout is properly set and read back.
- (void)testSetFetchTimeoutConfigSetting {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
    settings.fetchTimeout = 1;
    [_configInstances[i] setConfigSettings:settings];
    XCTAssertEqual([_configInstances[i] configSettings].fetchTimeout, 1);
    id<RCNConfigFetchSession> networkSession = [_configFetch[i] currentNetworkSession];
    XCTAssertNotNil(networkSession);
    XCTAssertEqual(networkSession.configuration.timeoutIntervalForResource, 1);
    XCTAssertEqual(networkSession.configuration.timeoutIntervalForRequest, 1);
  }
}

- (void)testFetchRequestWithUserPropertiesOnly {
  NSDictionary *userProperties = @{@"user_key" : @"user_value"};
  NSString *req = [_settings nextRequestWithUserProperties:userProperties];

  XCTAssertTrue([req containsString:@"analytics_user_properties:{\"user_key\":\"user_value\"}"]);
  XCTAssertFalse([req containsString:@"first_open_time"]);
}

- (void)testFetchRequestWithFirstOpenTimeAndUserProperties {
  NSDictionary *userProperties = @{@"_fot" : @1649116800000, @"user_key" : @"user_value"};
  NSString *req = [_settings nextRequestWithUserProperties:userProperties];

  XCTAssertTrue([req containsString:@"first_open_time:'2022-04-05T00:00:00Z'"]);
  XCTAssertTrue([req containsString:@"analytics_user_properties:{\"user_key\":\"user_value\"}"]);
}

- (void)testFetchRequestFirstOpenTimeOnly {
  NSDictionary *userProperties = @{@"_fot" : @1650315600000};
  NSString *req = [_settings nextRequestWithUserProperties:userProperties];

  XCTAssertTrue([req containsString:@"first_open_time:'2022-04-18T21:00:00Z'"]);
  XCTAssertFalse([req containsString:@"analytics_user_properties"]);
}

#pragma mark - Public Factory Methods

#ifdef FLAKY_TEST
- (void)testConfigureConfigWithValidInput {
  // Configure the default app with our options and ensure the Remote Config instance is set up
  // properly.
  if (![FIRApp isDefaultAppConfigured]) {
    XCTAssertNoThrow([FIRApp configureWithOptions:[self firstAppOptions]]);
  }
  XCTAssertNoThrow([FIRRemoteConfig remoteConfig]);
  FIRRemoteConfig *config = [FIRRemoteConfig remoteConfig];
  XCTAssertNotNil(config);

  // Ensure the same instance is returned from the singleton.
  FIRRemoteConfig *sameConfig = [FIRRemoteConfig remoteConfig];
  XCTAssertNotNil(sameConfig);
  XCTAssertEqual(config, sameConfig);

  // Ensure the app name is stored properly.
  XCTAssertEqual([config appName], kFIRDefaultAppName);
}
#endif

#pragma mark - Realtime tests

#ifdef AFTER_SWIFT_REWRITE
- (void)testRealtimeAddConfigUpdateListenerWithValidListener {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString
                stringWithFormat:@"Test Realtime add listener successfully - instance %d", i]];

    OCMStub([_configRealtime[i] beginRealtimeStream]).andDo(nil);
    id completion = ^void(FIRRemoteConfigUpdate *_Nullable configUpdate, NSError *_Nullable error) {
      if (error != nil) {
        NSLog(@"Callback");
      }
    };

    [_configRealtime[i] addConfigUpdateListener:completion];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify([self->_configRealtime[i] beginRealtimeStream]);
          OCMVerify([self->_configRealtime[i] addConfigUpdateListener:completion]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}

- (void)testRealtimeAddConfigUpdateListenerWithInvalidListener {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString
                stringWithFormat:@"Test Realtime add listener unsuccessfully - instance %d", i]];

    id completion = nil;
    [_configRealtime[i] addConfigUpdateListener:completion];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify(never(), [self->_configRealtime[i] beginRealtimeStream]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}

- (void)testRemoveRealtimeListener {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString
                stringWithFormat:@"Test Realtime remove listeners successfully - instance %d", i]];

    id completion = ^void(FIRRemoteConfigUpdate *_Nullable configUpdate, NSError *_Nullable error) {
      if (error != nil) {
        NSLog(@"Callback");
      }
    };
    OCMStub([_configRealtime[i] beginRealtimeStream]).andDo(nil);

    FIRConfigUpdateListenerRegistration *registration =
        [_configRealtime[i] addConfigUpdateListener:completion];
    [registration remove];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify([self->_configRealtime[i] addConfigUpdateListener:completion]);
          OCMVerify([self->_configRealtime[i] removeConfigUpdateListener:completion]);
          OCMVerify([self->_configRealtime[i] pauseRealtimeStream]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}

// TODO(ncooke3): ConfigFetch cannot be mocked so rethink this test.
- (void)SKIP_testRealtimeFetch {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test Realtime Autofetch successfully - instance %d", i]];

    OCMStub([_configFetch[i] realtimeFetchConfigWithNoExpirationDuration:1
                                                       completionHandler:OCMOCK_ANY])
        .andDo(nil);
    OCMStub([_configRealtime[i] scheduleFetch:1 targetVersion:1]).andDo(nil);

    [_configRealtime[i] fetchLatestConfig:3 targetVersion:1];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify([self->_configFetch[i] realtimeFetchConfigWithNoExpirationDuration:1
                                                                     completionHandler:OCMOCK_ANY]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}

- (void)testAutofetch {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test Realtime Autofetch successfully - instance %d", i]];

    OCMStub([_configRealtime[i] scheduleFetch:1 targetVersion:1]).andDo(nil);

    [_configRealtime[i] autoFetch:1 targetVersion:1];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify([self->_configRealtime[i] scheduleFetch:1 targetVersion:1]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}

- (void)testAddOnConfigUpdateMethodSuccess {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString
                stringWithFormat:@"Test public realtime method successfully - instance %d", i]];

    OCMStub([_configRealtime[i] beginRealtimeStream]).andDo(nil);

    id completion = ^void(FIRRemoteConfigUpdate *_Nullable configUpdate, NSError *_Nullable error) {
      if (error != nil) {
        NSLog(@"Callback");
      }
    };
    [_configInstances[i] addOnConfigUpdateListener:completion];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify([self->_configRealtime[i] addConfigUpdateListener:completion]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}

// TODO: Modify this test since the listener should not be nullable - verify beginRealtimeStream
// starts - and calls into listener?
- (void)testAddOnConfigUpdateMethodFail {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test public realtime method and fails - instance %d", i]];

    id completion = nil;
    [_configInstances[i] addOnConfigUpdateListener:completion];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify(never(), [self->_configRealtime[i] beginRealtimeStream]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}

- (void)testRealtimeDisabled {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString
                stringWithFormat:@"Test isRealtimeDisabled flag and makes it true - instance %d",
                                 i]];
    OCMStub([_configRealtime[i] pauseRealtimeStream]).andDo(nil);
    NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    [dictionary setValue:@"true" forKey:@"featureDisabled"];
    [dictionary setValue:@"1" forKey:@"latestTemplateVersionNumber"];

    [_configRealtime[i] evaluateStreamResponse:dictionary];
    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          OCMVerify([self->_configRealtime[i] pauseRealtimeStream]);
          OCMVerify(never(), [self->_configRealtime[i] autoFetch:5 targetVersion:1]);
          [expectations[i] fulfill];
        });

    [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
  }
}
#endif

- (void)testRealtimeStreamRequestBody {
  XCTestExpectation *requestBodyExpectation = [self expectationWithDescription:@"requestBody"];
  __block NSData *requestBody;
  [_configRealtime[0] createRequestBodyWithCompletion:^(NSData *_Nonnull data) {
    requestBody = data;
    [requestBodyExpectation fulfill];
  }];
  [self waitForExpectations:@[ requestBodyExpectation ] timeout:5.0];
  NSError *error;
  NSData *uncompressedRequest = [NSData gul_dataByInflatingGzippedData:requestBody error:&error];
  NSString *strData = [[NSString alloc] initWithData:uncompressedRequest
                                            encoding:NSUTF8StringEncoding];

  XCTAssertTrue([strData containsString:@"project:'correct_gcm_sender_id'"]);
  XCTAssertTrue([strData containsString:@"namespace:'firebase'"]);
  XCTAssertTrue([strData containsString:@"lastKnownVersionNumber:'0'"]);
  XCTAssertTrue([strData containsString:@"appId:'1:123:ios:123abc'"]);
  XCTAssertTrue([strData containsString:@"sdkVersion:"]);
  XCTAssertTrue([strData containsString:@"appInstanceId:'iid'"]);
}

// Test fails with a mocking problem on TVOS. Reenable in Swift.
#if INVESTIGATE_FLAKINESS
- (void)testFetchAndActivateRolloutsNotifyInterop {
  XCTestExpectation *notificationExpectation =
      [self expectationForNotification:@"FIRRolloutsStateDidChangeNotification"
                                object:nil
                               handler:nil];

  XCTAssertEqual(_configInstances[RCNTestRCInstanceDefault].lastFetchStatus,
                 FIRRemoteConfigFetchStatusNoFetchYet);

  FIRRemoteConfigFetchAndActivateCompletion fetchAndActivateCompletion =
      ^void(FIRRemoteConfigFetchAndActivateStatus status, NSError *error) {
        XCTAssertEqual(status, FIRRemoteConfigFetchAndActivateStatusSuccessFetchedFromRemote);
        XCTAssertNil(error);

        XCTAssertEqual(self->_configInstances[RCNTestRCInstanceDefault].lastFetchStatus,
                       FIRRemoteConfigFetchStatusSuccess);
        XCTAssertNotNil(self->_configInstances[RCNTestRCInstanceDefault].lastFetchTime);
        XCTAssertGreaterThan(
            self->_configInstances[RCNTestRCInstanceDefault].lastFetchTime.timeIntervalSince1970, 0,
            @"last fetch time interval should be set.");
        [notificationExpectation fulfill];
      };

  [_configInstances[RCNTestRCInstanceDefault]
      fetchAndActivateWithCompletionHandler:fetchAndActivateCompletion];
  [self waitForExpectations:@[ notificationExpectation ] timeout:_expectationTimeout];
}
#endif

#pragma mark - Test Helpers

- (FIROptions *)firstAppOptions {
  // TODO: Evaluate if we want to hardcode things here instead.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123abc"
                                                    GCMSenderID:@"correct_gcm_sender_id"];
  options.APIKey = @"AIzaSy-ApiKeyWithValidFormat_0123456789";
  options.projectID = @"abc-xyz-123";
  return options;
}

- (FIROptions *)secondAppOptions {
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
#if SWIFT_PACKAGE
  bundle = SWIFTPM_MODULE_BUNDLE;
#endif
  NSString *plistPath = [bundle pathForResource:@"SecondApp-GoogleService-Info" ofType:@"plist"];
  FIROptions *options = [[FIROptions alloc] initWithContentsOfFile:plistPath];
  XCTAssertNotNil(options);
  return options;
}

@end
