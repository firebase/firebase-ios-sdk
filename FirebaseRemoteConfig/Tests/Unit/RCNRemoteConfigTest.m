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
#import <GoogleUtilities/GULNSData+zlib.h>
#import <OCMock/OCMStubRecorder.h>
#import <OCMock/OCMock.h>

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
- (void)fetchWithUserPropertiesCompletionHandler:(FIRAInteropUserPropertiesCallback)block;
- (NSURLSessionDataTask *)URLSessionDataTaskWithContent:(NSData *)content
                                      completionHandler:
                                          (RCNConfigFetcherCompletion)fetcherCompletion;

- (void)fetchWithUserProperties:(NSDictionary *)userProperties
              completionHandler:(void (^_Nullable)(FIRRemoteConfigFetchStatus status,
                                                   NSError *_Nullable error))completionHandler;
- (NSString *)constructServerURL;
- (NSURLSession *)currentNetworkSession;
@end

@interface FIRRemoteConfig (ForTest)
- (void)updateWithNewInstancesForConfigFetch:(RCNConfigFetch *)configFetch
                               configContent:(RCNConfigContent *)configContent
                              configSettings:(RCNConfigSettings *)configSettings
                            configExperiment:(RCNConfigExperiment *)configExperiment;
@end

@implementation FIRRemoteConfig (ForTest)
- (void)updateWithNewInstancesForConfigFetch:(RCNConfigFetch *)configFetch
                               configContent:(RCNConfigContent *)configContent
                              configSettings:(RCNConfigSettings *)configSettings
                            configExperiment:(RCNConfigExperiment *)configExperiment {
  [self setValue:configFetch forKey:@"_configFetch"];
  [self setValue:configContent forKey:@"_configContent"];
  [self setValue:configSettings forKey:@"_settings"];
  [self setValue:configExperiment forKey:@"_configExperiment"];
}
@end

@interface RCNConfigDBManager (Test)
- (void)removeDatabaseOnDatabaseQueueAtPath:(NSString *)path;
@end

@interface RCNUserDefaultsManager (Test)
+ (NSUserDefaults *)sharedUserDefaultsForBundleIdentifier:(NSString *)bundleIdentifier;
@end

typedef NS_ENUM(NSInteger, RCNTestRCInstance) {
  RCNTestRCInstanceDefault,
  RCNTestRCNumTotalInstances,  // TODO(mandard): Remove once OCMock issue is resolved (#4877).
  RCNTestRCInstanceSecondNamespace,
  RCNTestRCInstanceSecondApp,
};

@interface RCNRemoteConfigTest : XCTestCase {
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
  id _DBManagerMock;
  id _userDefaultsMock;
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
  _DBManagerMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([_DBManagerMock remoteConfigPathForDatabase]).andReturn(_DBPath);
  _DBManager = [[RCNConfigDBManager alloc] init];

  _userDefaultsSuiteName = [RCNTestUtilities userDefaultsSuiteNameForTestSuite];
  _userDefaults = [[NSUserDefaults alloc] initWithSuiteName:_userDefaultsSuiteName];
  _userDefaultsMock = OCMClassMock([RCNUserDefaultsManager class]);
  OCMStub([_userDefaultsMock sharedUserDefaultsForBundleIdentifier:[OCMArg any]])
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

    OCMStubRecorder *mock = OCMStub([_configFetch[i] fetchConfigWithExpirationDuration:0
                                                                     completionHandler:OCMOCK_ANY]);
    mock = [mock ignoringNonObjectArgs];
    mock.andDo(^(NSInvocation *invocation) {
      __unsafe_unretained void (^handler)(FIRRemoteConfigFetchStatus status,
                                          NSError *_Nullable error) = nil;
      [invocation getArgument:&handler atIndex:3];
      [self->_configFetch[i] fetchWithUserProperties:[[NSDictionary alloc] init]
                                   completionHandler:handler];
    });

    _response[i] = @{@"state" : @"UPDATE", @"entries" : _entries[i]};

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    _URLResponse[i] = [[NSHTTPURLResponse alloc]
         initWithURL:[NSURL URLWithString:@"https://firebase.com"]
          statusCode:200
         HTTPVersion:nil
        headerFields:@{@"etag" : [NSString stringWithFormat:@"etag1-%d", i]}];

    id completionBlock =
        [OCMArg invokeBlockWithArgs:_responseData[i], _URLResponse[i], [NSNull null], nil];

    OCMExpect([_configFetch[i] URLSessionDataTaskWithContent:[OCMArg any]
                                           completionHandler:completionBlock])
        .andReturn(nil);
    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
                                                configContent:configContent
                                               configSettings:settings
                                             configExperiment:nil];
  }
}

- (void)tearDown {
  [_DBManager removeDatabaseOnDatabaseQueueAtPath:_DBPath];
  [[NSUserDefaults standardUserDefaults] removePersistentDomainForName:_userDefaultsSuiteName];
  [_DBManagerMock stopMocking];
  _DBManagerMock = nil;
  [_userDefaultsMock stopMocking];
  _userDefaultsMock = nil;
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    [(id)_configInstances[i] stopMocking];
    [(id)_configFetch[i] stopMocking];
  }
  [_configInstances removeAllObjects];
  [_configFetch removeAllObjects];
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

- (void)testFetchConfigsSuccessfully {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:
                  [NSString stringWithFormat:@"Test fetch configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      XCTAssertTrue([self->_configInstances[i] activateFetched]);
#pragma clang diagnostic pop
      NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
      NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
      NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
      NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
      XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);

      OCMVerify([self->_configInstances[i] objectForKeyedSubscript:key1]);

      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                     @"Callback of first successful config "
                     @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccessFresh.");

      XCTAssertNotNil(self->_configInstances[i].lastFetchTime);
      XCTAssertGreaterThan(self->_configInstances[i].lastFetchTime.timeIntervalSince1970, 0,
                           @"last fetch time interval should be set.");
      [expectations[i] fulfill];
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
    void (^fetchAndActivateCompletion)(
        FIRRemoteConfigFetchAndActivateStatus status,
        NSError *error) = ^void(FIRRemoteConfigFetchAndActivateStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);

      NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
      NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
      NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
      NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
      XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);

      OCMVerify([self->_configInstances[i] objectForKeyedSubscript:key1]);

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
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      [self->_configInstances[i] activateWithCompletionHandler:^(NSError *_Nullable error) {
        XCTAssertNil(error);
        NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
        NSString *key2 = [NSString stringWithFormat:@"key2-%d", i];
        NSString *value1 = [NSString stringWithFormat:@"value1-%d", i];
        NSString *value2 = [NSString stringWithFormat:@"value2-%d", i];
        XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
        XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);

        OCMVerify([self->_configInstances[i] objectForKeyedSubscript:key1]);

        XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                       @"Callback of first successful config "
                       @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccessFresh.");

        XCTAssertNotNil(self->_configInstances[i].lastFetchTime);
        XCTAssertGreaterThan(self->_configInstances[i].lastFetchTime.timeIntervalSince1970, 0,
                             @"last fetch time interval should be set.");
        // A second activate should return an error.
        [self->_configInstances[i] activateWithCompletionHandler:^(NSError *_Nullable error) {
          XCTAssertNotNil(error);
          XCTAssertEqualObjects(error.domain, FIRRemoteConfigErrorDomain);
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
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      XCTAssertTrue([self->_configInstances[i] activateFetched]);
#pragma clang diagnostic pop
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
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
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
    RCNUserDefaultsManager *userDefaultsManager =
        [[RCNUserDefaultsManager alloc] initWithAppName:currentAppName
                                               bundleID:[NSBundle mainBundle].bundleIdentifier
                                              namespace:fullyQualifiedNamespace];
    userDefaultsManager.lastFetchTime = 0;

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

    OCMStub([_configFetch[i] fetchConfigWithExpirationDuration:43200 completionHandler:OCMOCK_ANY])
        .andDo(^(NSInvocation *invocation) {
          __unsafe_unretained void (^handler)(FIRRemoteConfigFetchStatus status,
                                              NSError *_Nullable error) = nil;
          // void (^handler)(FIRRemoteConfigFetchCompletion);
          [invocation getArgument:&handler atIndex:3];
          [self->_configFetch[i] fetchWithUserProperties:[[NSDictionary alloc] init]
                                       completionHandler:handler];
        });

    _response[i] = @{};

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    _URLResponse[i] =
        [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://firebase.com"]
                                    statusCode:500
                                   HTTPVersion:nil
                                  headerFields:@{@"etag" : @"etag1"}];

    id completionBlock =
        [OCMArg invokeBlockWithArgs:_responseData[i], _URLResponse[i], [NSNull null], nil];

    OCMExpect([_configFetch[i] URLSessionDataTaskWithContent:[OCMArg any]
                                           completionHandler:completionBlock])
        .andReturn(nil);
    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
                                                configContent:configContent
                                               configSettings:settings
                                             configExperiment:nil];
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // Make the fetch calls for all instances.
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test enumerating configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusFailure);
      XCTAssertFalse([self->_configInstances[i] activateFetched]);
      XCTAssertNotNil(error);
      // No such key, still return a static value.
      FIRRemoteConfigValue *value = self->_configInstances[RCNTestRCInstanceDefault][@"key1"];
      XCTAssertEqual((int)value.source, (int)FIRRemoteConfigSourceStatic);
      XCTAssertEqualObjects(value.stringValue, @"");
      XCTAssertEqual(value.boolValue, NO);
      [expectations[i] fulfill];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
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
    RCNUserDefaultsManager *userDefaultsManager =
        [[RCNUserDefaultsManager alloc] initWithAppName:currentAppName
                                               bundleID:[NSBundle mainBundle].bundleIdentifier
                                              namespace:fullyQualifiedNamespace];
    userDefaultsManager.lastFetchTime = 0;

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

    OCMStub([_configFetch[i] fetchConfigWithExpirationDuration:43200 completionHandler:OCMOCK_ANY])
        .andDo(^(NSInvocation *invocation) {
          __unsafe_unretained void (^handler)(FIRRemoteConfigFetchStatus status,
                                              NSError *_Nullable error) = nil;
          // void (^handler)(FIRRemoteConfigFetchCompletion);
          [invocation getArgument:&handler atIndex:3];
          [self->_configFetch[i] fetchWithUserProperties:[[NSDictionary alloc] init]
                                       completionHandler:handler];
        });

    _response[i] = @{};

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    // A no network error is accompanied with an HTTP status code of 0.
    _URLResponse[i] =
        [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://firebase.com"]
                                    statusCode:0
                                   HTTPVersion:nil
                                  headerFields:@{@"etag" : @"etag1"}];

    id completionBlock =
        [OCMArg invokeBlockWithArgs:_responseData[i], _URLResponse[i], [NSNull null], nil];

    OCMExpect([_configFetch[i] URLSessionDataTaskWithContent:[OCMArg any]
                                           completionHandler:completionBlock])
        .andReturn(nil);
    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
                                                configContent:configContent
                                               configSettings:settings
                                             configExperiment:nil];
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // Make the fetch calls for all instances.
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test enumerating configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusFailure);
      XCTAssertFalse([self->_configInstances[i] activateFetched]);
      XCTAssertNotNil(error);
      // No such key, still return a static value.
      FIRRemoteConfigValue *value = self->_configInstances[RCNTestRCInstanceDefault][@"key1"];
      XCTAssertEqual((int)value.source, (int)FIRRemoteConfigSourceStatic);
      XCTAssertEqualObjects(value.stringValue, @"");
      XCTAssertEqual(value.boolValue, NO);
      [expectations[i] fulfill];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
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
    RCNUserDefaultsManager *userDefaultsManager =
        [[RCNUserDefaultsManager alloc] initWithAppName:currentAppName
                                               bundleID:[NSBundle mainBundle].bundleIdentifier
                                              namespace:fullyQualifiedNamespace];
    userDefaultsManager.lastFetchTime = 10;

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
    // Start the test with the assumption that we have some data that was fetched and activated.
    settings.lastETag = @"etag1";
    settings.lastETagUpdateTime = 100;
    settings.lastApplyTimeInterval = 101;

    dispatch_queue_t queue =
        dispatch_queue_create([[NSString stringWithFormat:@"testNoStatusFetchQueue: %d", i]
                                  cStringUsingEncoding:NSUTF8StringEncoding],
                              DISPATCH_QUEUE_SERIAL);
    _configFetch[i] = OCMPartialMock([[RCNConfigFetch alloc] initWithContent:configContent
                                                                   DBManager:_DBManager
                                                                    settings:settings
                                                                   analytics:nil
                                                                  experiment:nil
                                                                       queue:queue
                                                                   namespace:fullyQualifiedNamespace
                                                                     options:currentOptions]);

    OCMStub([_configFetch[i] fetchConfigWithExpirationDuration:43200 completionHandler:OCMOCK_ANY])
        .andDo(^(NSInvocation *invocation) {
          __unsafe_unretained void (^handler)(FIRRemoteConfigFetchStatus status,
                                              NSError *_Nullable error) = nil;

          [invocation getArgument:&handler atIndex:3];
          [self->_configFetch[i] fetchWithUserProperties:[[NSDictionary alloc] init]
                                       completionHandler:handler];
        });

    _response[i] = @{@"state" : @"NO_CHANGE"};

    _responseData[i] = [NSJSONSerialization dataWithJSONObject:_response[i] options:0 error:nil];

    _URLResponse[i] =
        [[NSHTTPURLResponse alloc] initWithURL:[NSURL URLWithString:@"https://firebase.com"]
                                    statusCode:200
                                   HTTPVersion:nil
                                  headerFields:@{@"etag" : @"etag1"}];

    id completionBlock =
        [OCMArg invokeBlockWithArgs:_responseData[i], _URLResponse[i], [NSNull null], nil];

    OCMExpect([_configFetch[i] URLSessionDataTaskWithContent:[OCMArg any]
                                           completionHandler:completionBlock])
        .andReturn(nil);
    [_configInstances[i] updateWithNewInstancesForConfigFetch:_configFetch[i]
                                                configContent:configContent
                                               configSettings:settings
                                             configExperiment:nil];
  }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  // Make the fetch calls for all instances.
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];

  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test enumerating configs successfully - instance %d", i]];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);

    // Make sure activate returns false in fetch completion.
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertFalse([self->_configInstances[i] activateFetched]);
      XCTAssertNil(error);
      [expectations[i] fulfill];
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
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      XCTAssertTrue([self->_configInstances[i] activateFetched]);

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
      OCMVerify([self->_configInstances[i] objectForKeyedSubscript:key1]);
      XCTAssertEqualObjects([self->_configInstances[i] configValueForKey:key3].stringValue, value3);
      if (i == RCNTestRCInstanceDefault) {
        XCTAssertEqualObjects(
            [self->_configInstances[i] configValueForKey:key7
                                               namespace:FIRNamespaceGoogleMobilePlatform]
                .stringValue,
            value7);
      }

      XCTAssertEqualObjects([self->_configInstances[i] configValueForKey:key7].stringValue, value7);
      XCTAssertNotNil([self->_configInstances[i] configValueForKey:nil]);
      XCTAssertEqual([self->_configInstances[i] configValueForKey:nil].source,
                     FIRRemoteConfigSourceStatic);
      XCTAssertEqual([self->_configInstances[i] configValueForKey:nil namespace:nil].source,
                     FIRRemoteConfigSourceStatic);
      XCTAssertEqual(
          [self->_configInstances[i] configValueForKey:nil namespace:nil source:-1].source,
          FIRRemoteConfigSourceStatic);

      [expectations[i] fulfill];
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

    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, @"default key1");
      XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceDefault);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      XCTAssertTrue([self->_configInstances[i] activateFetched]);
#pragma clang diagnostic pop
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
      XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceRemote);
      XCTAssertEqualObjects([self->_configInstances[i] defaultValueForKey:key1].stringValue,
                            @"default key1");
      XCTAssertEqualObjects(self->_configInstances[i][key2].stringValue, value2);
      XCTAssertEqualObjects(self->_configInstances[i][key0].stringValue, @"value0-0");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      XCTAssertNil([self->_configInstances[i] defaultValueForKey:nil namespace:nil]);
#pragma clang diagnostic pop
      OCMVerify([self->_configInstances[i] objectForKeyedSubscript:key1]);
      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                     @"Callback of first successful config "
                     @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccess.");
      [fetchConfigsExpectation[i] fulfill];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

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
      [_configInstances[i] setDefaults:defaults namespace:RCNTestsPerfNamespace];
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
          [_configInstances[i] configValueForKey:@"experience" namespace:RCNTestsPerfNamespace]
              .stringValue,
          @"2860", @"Only default config has the key, must equal to default config value.");
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
    [_configInstances[i] setDefaults:nil namespace:nil];

    dispatch_after(
        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_checkCompletionTimeout * NSEC_PER_SEC)),
        dispatch_get_main_queue(), ^{
          XCTAssertEqual(
              [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault
                                                 namespace:FIRNamespaceGoogleMobilePlatform]
                  .count,
              0);
          [expectations[i] fulfill];
        });
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}

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

    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      XCTAssertTrue([self->_configInstances[i] activateFetched]);
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
      XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceRemote);
      XCTAssertEqualObjects([self->_configInstances[i] defaultValueForKey:key1].stringValue,
                            @"default key1");
      OCMVerify([self->_configInstances[i] objectForKeyedSubscript:key1]);

      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess,
                     @"Callback of first successful config "
                     @"fetch. Status must equal to FIRRemoteConfigFetchStatusSuccess.");
      [fetchConfigsExpectation[i] fulfill];
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

    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(self->_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, @"default value1");
      XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceDefault);
      XCTAssertTrue([self->_configInstances[i] activateFetched]);
      XCTAssertEqualObjects(self->_configInstances[i][key1].stringValue, value1);
      XCTAssertEqual(self->_configInstances[i][key1].source, FIRRemoteConfigSourceRemote);
      FIRRemoteConfigValue *value;
      if (i == RCNTestRCInstanceDefault) {
        value = [self->_configInstances[i] configValueForKey:key1
                                                   namespace:FIRNamespaceGoogleMobilePlatform
                                                      source:FIRRemoteConfigSourceRemote];
        XCTAssertEqualObjects(value.stringValue, value1);
        value = [self->_configInstances[i] configValueForKey:key1
                                                   namespace:FIRNamespaceGoogleMobilePlatform
                                                      source:FIRRemoteConfigSourceDefault];
        XCTAssertEqualObjects(value.stringValue, @"default value1");
        value = [self->_configInstances[i] configValueForKey:key1
                                                   namespace:FIRNamespaceGoogleMobilePlatform
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
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout handler:nil];
}

- (void)testInvalidKeyOrNamespace {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    FIRRemoteConfigValue *value = [_configInstances[i] configValueForKey:nil];
    XCTAssertNotNil(value);
    XCTAssertEqual(value.source, FIRRemoteConfigSourceStatic);

    value = [_configInstances[i] configValueForKey:nil namespace:nil];
    XCTAssertNotNil(value);
    XCTAssertEqual(value.source, FIRRemoteConfigSourceStatic);

    value = [_configInstances[i] configValueForKey:nil namespace:nil source:5];
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

- (void)testSetDefaultsFromPlist {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    FIRRemoteConfig *config = _configInstances[i];
    [config setDefaultsFromPlistFileName:@"Defaults-testInfo"];
    XCTAssertEqualObjects(_configInstances[i][@"lastCheckTime"].stringValue,
                          UTCToLocal(@"2016-02-28 18:33:31"));
    XCTAssertEqual(_configInstances[i][@"isPaidUser"].boolValue, YES);
    XCTAssertEqualObjects(_configInstances[i][@"dataValue"].stringValue, @"2.4");
    XCTAssertEqualObjects(_configInstances[i][@"New item"].numberValue, @(2.4));
    XCTAssertEqualObjects(_configInstances[i][@"Languages"].stringValue, @"English");
    XCTAssertEqualObjects(_configInstances[i][@"FileInfo"].stringValue,
                          @"To setup default config.");
    XCTAssertEqualObjects(_configInstances[i][@"format"].stringValue, @"key to value.");

    // If given a wrong file name, the default will not be set and kept as previous results.
    [_configInstances[i] setDefaultsFromPlistFileName:@""];
    XCTAssertEqualObjects(_configInstances[i][@"lastCheckTime"].stringValue,
                          UTCToLocal(@"2016-02-28 18:33:31"));
    [_configInstances[i] setDefaultsFromPlistFileName:@"non-existed_file"];
    XCTAssertEqualObjects(_configInstances[i][@"dataValue"].stringValue, @"2.4");
    [_configInstances[i] setDefaultsFromPlistFileName:nil namespace:nil];
    XCTAssertEqualObjects(_configInstances[i][@"New item"].numberValue, @(2.4));
    [_configInstances[i] setDefaultsFromPlistFileName:@"" namespace:@""];
    XCTAssertEqualObjects(_configInstances[i][@"Languages"].stringValue, @"English");
  }
}

- (void)testSetDefaultsAndNamespaceFromPlist {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    if (i == RCNTestRCInstanceDefault) {
      [_configInstances[i] setDefaultsFromPlistFileName:@"Defaults-testInfo"
                                              namespace:RCNTestsPerfNamespace];
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"lastCheckTime"
                                                         namespace:RCNTestsPerfNamespace]
                                .stringValue,
                            UTCToLocal(@"2016-02-28 18:33:31"));
      XCTAssertEqual([_configInstances[i] configValueForKey:@"isPaidUser"
                                                  namespace:RCNTestsPerfNamespace]
                         .boolValue,
                     YES);
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"dataValue"
                                                         namespace:RCNTestsPerfNamespace]
                                .stringValue,
                            @"2.4");
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"New item"
                                                         namespace:RCNTestsPerfNamespace]
                                .numberValue,
                            @(2.4));
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"Languages"
                                                         namespace:RCNTestsPerfNamespace]
                                .stringValue,
                            @"English");
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"FileInfo"
                                                         namespace:RCNTestsPerfNamespace]
                                .stringValue,
                            @"To setup default config.");
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"format"
                                                         namespace:RCNTestsPerfNamespace]
                                .stringValue,
                            @"key to value.");
    } else {
      [_configInstances[i] setDefaultsFromPlistFileName:@"Defaults-testInfo"];
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"lastCheckTime"].stringValue,
                            UTCToLocal(@"2016-02-28 18:33:31"));
      XCTAssertEqual([_configInstances[i] configValueForKey:@"isPaidUser"].boolValue, YES);
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"dataValue"].stringValue,
                            @"2.4");
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"New item"].numberValue,
                            @(2.4));
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"Languages"].stringValue,
                            @"English");
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"FileInfo"].stringValue,
                            @"To setup default config.");
      XCTAssertEqualObjects([_configInstances[i] configValueForKey:@"format"].stringValue,
                            @"key to value.");
    }
  }
}

- (void)testSetDeveloperMode {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    XCTAssertFalse(_configInstances[i].configSettings.isDeveloperModeEnabled);
    FIRRemoteConfigSettings *settings =
        [[FIRRemoteConfigSettings alloc] initWithDeveloperModeEnabled:YES];

    _configInstances[i].configSettings = settings;
    XCTAssertTrue(_configInstances[i].configSettings.isDeveloperModeEnabled);
  }
}

- (void)testAllKeysFromSource {
  NSMutableArray<XCTestExpectation *> *fetchConfigsExpectation =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    fetchConfigsExpectation[i] = [self
        expectationWithDescription:[NSString
                                       stringWithFormat:@"Test allKeys methods - instance %d", i]];
    NSString *key1 = [NSString stringWithFormat:@"key1-%d", i];
    NSString *key0 = [NSString stringWithFormat:@"key0-%d", i];
    NSDictionary<NSString *, NSString *> *defaults = @{key1 : @"default key1", key0 : @"value0-0"};
    [_configInstances[i] setDefaults:defaults];

    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      XCTAssertTrue([self->_configInstances[i] activateFetched]);

      if (i == RCNTestRCInstanceDefault) {
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceRemote
                                               namespace:FIRNamespaceGoogleMobilePlatform]
                .count,
            100);
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault
                                               namespace:FIRNamespaceGoogleMobilePlatform]
                .count,
            2);
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceStatic
                                               namespace:FIRNamespaceGoogleMobilePlatform]
                .count,
            0);
      } else {
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceRemote].count, 100);
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault].count, 2);
        XCTAssertEqual(
            [self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceStatic].count, 0);
      }

      XCTAssertNotNil([self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceRemote
                                                         namespace:@"invalid namespace"]);
      XCTAssertEqual([self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceRemote
                                                        namespace:@"invalid namespace"]
                         .count,
                     0);
      XCTAssertNotNil([self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceRemote
                                                         namespace:nil]);
      XCTAssertEqual([self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceRemote
                                                        namespace:nil]
                         .count,
                     0);
      XCTAssertNotNil([self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault
                                                         namespace:nil]);
      XCTAssertEqual([self->_configInstances[i] allKeysFromSource:FIRRemoteConfigSourceDefault
                                                        namespace:nil]
                         .count,
                     0);

      [fetchConfigsExpectation[i] fulfill];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testAllKeysWithPrefix {
  NSMutableArray<XCTestExpectation *> *fetchConfigsExpectation =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    fetchConfigsExpectation[i] = [self
        expectationWithDescription:[NSString
                                       stringWithFormat:@"Test allKeys methods - instance %d", i]];
    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) = ^void(
        FIRRemoteConfigFetchStatus status, NSError *error) {
      XCTAssertEqual(status, FIRRemoteConfigFetchStatusSuccess);
      XCTAssertNil(error);
      NSLog(@"Testing _configInstances %d", i);
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
      XCTAssertTrue([self->_configInstances[i] activateFetched]);

      // Test keysWithPrefix:namespace: method.
      if (i == RCNTestRCInstanceDefault) {
        XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"key"
                                                       namespace:FIRNamespaceGoogleMobilePlatform]
                           .count,
                       100);
      } else {
        XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"key"].count, 100);
      }

      XCTAssertEqual(
          [self->_configInstances[i] keysWithPrefix:@"pl" namespace:@"invalid namespace"].count, 0);
      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"pl" namespace:nil].count, 0);
      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"pl" namespace:@""].count, 0);

      XCTAssertNotNil([self->_configInstances[i] keysWithPrefix:nil namespace:nil]);
      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:nil namespace:nil].count, 0);
#pragma clang diagnostic pop

      // Test keysWithPrefix: method.
      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"key1"].count, 12);
      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"key"].count, 100);

      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@"invalid key"].count, 0);
      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:nil].count, 100);
      XCTAssertEqual([self->_configInstances[i] keysWithPrefix:@""].count, 100);

      [fetchConfigsExpectation[i] fulfill];
    };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testSetDeveloperModeConfigSetting {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    FIRRemoteConfigSettings *settings =
        [[FIRRemoteConfigSettings alloc] initWithDeveloperModeEnabled:YES];
    [_configInstances[i] setConfigSettings:settings];
    XCTAssertTrue([_configInstances[i] configSettings].isDeveloperModeEnabled);

    settings = [[FIRRemoteConfigSettings alloc] initWithDeveloperModeEnabled:NO];
    [_configInstances[i] setConfigSettings:settings];
    XCTAssertFalse([_configInstances[i] configSettings].isDeveloperModeEnabled);
#pragma clang diagnostic pop
  }
}

/// Test the minimum fetch interval is applied and read back correctly.
- (void)testSetMinimumFetchIntervalConfigSetting {
  NSMutableArray<XCTestExpectation *> *fetchConfigsExpectation =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    fetchConfigsExpectation[i] = [self
        expectationWithDescription:
            [NSString stringWithFormat:@"Test minimumFetchInterval expectation - instance %d", i]];
    FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
    settings.minimumFetchInterval = 123;
    [_configInstances[i] setConfigSettings:settings];
    XCTAssertEqual([_configInstances[i] configSettings].minimumFetchInterval, 123);

    void (^fetchCompletion)(FIRRemoteConfigFetchStatus status, NSError *error) =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertFalse([self->_configInstances[i].settings hasMinimumFetchIntervalElapsed:43200]);

          // Update minimum fetch interval.
          FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
          settings.minimumFetchInterval = 0;
          [self->_configInstances[i] setConfigSettings:settings];
          XCTAssertEqual([self->_configInstances[i] configSettings].minimumFetchInterval, 0);
          XCTAssertTrue([self->_configInstances[i].settings hasMinimumFetchIntervalElapsed:0]);
          [fetchConfigsExpectation[i] fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }
  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/// Test the fetch timeout is properly set and read back.
- (void)testSetFetchTimeoutConfigSetting {
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    FIRRemoteConfigSettings *settings = [[FIRRemoteConfigSettings alloc] init];
    settings.fetchTimeout = 1;
    [_configInstances[i] setConfigSettings:settings];
    XCTAssertEqual([_configInstances[i] configSettings].fetchTimeout, 1);
    NSURLSession *networkSession = [_configFetch[i] currentNetworkSession];
    XCTAssertNotNil(networkSession);
    XCTAssertEqual(networkSession.configuration.timeoutIntervalForResource, 1);
    XCTAssertEqual(networkSession.configuration.timeoutIntervalForRequest, 1);
  }
}

#pragma mark - Public Factory Methods

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
  XCTAssertEqual([config valueForKey:@"_appName"], kFIRDefaultAppName);
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
