#import <XCTest/XCTest.h>

#import "FirebaseRemoteConfig/Sources/Public/FIRRemoteConfig.h"
#import "FirebaseRemoteConfig/Sources/FIRRemoteConfig_Internal.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigFetch.h"
#import "FirebaseRemoteConfig/Sources/RCNUserDefaultsManager.h"

#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

#import <FirebaseCore/FIROptions.h>
#import <FirebaseCore//FIRAppInternal.h>
#import <FirebaseCore//FIRLogger.h>
#import <GoogleUtilities/NSData+zlib/GULNSData+zlib.h>
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
              completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler;
- (NSString *)constructServerURL;
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
  RCNTestRCInstanceSecondNamespace,
  RCNTestRCInstanceSecondApp,
  RCNTestRCNumTotalInstances
};

@interface RCNFeaturesTest : XCTestCase {
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
}
@end

@implementation RCNFeaturesTest
- (void)setUp {
  [super setUp];
  FIRSetLoggerLevel(FIRLoggerLevelMax);

  _expectationTimeout = 5;
  _checkCompletionTimeout = 1.0;

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

    OCMStub([_configFetch[i] fetchAllConfigsWithExpirationDuration:43200
                                                 completionHandler:OCMOCK_ANY])
        .andDo(^(NSInvocation *invocation) {
          void (^handler)(FIRRemoteConfigFetchStatus status, NSError *_Nullable error) = nil;
          // void (^handler)(FIRRemoteConfigFetchCompletion);
          [invocation getArgument:&handler atIndex:3];
          [_configFetch[i] fetchWithUserProperties:[[NSDictionary alloc] init]
                                 completionHandler:handler];
        });

    // Add features and rollouts information.
    NSArray *rolloutsInfo = @[ @{
      @"rollout" : @"projects/12345/rollouts/123",
      @"featureKey" : @"test_featureB",
      @"featureEnabled" : @YES
    } ];
    _response[i] = @{
      @"state" : @"UPDATE",
      @"entries" : _entries[i],
      @"enabledFeatureKeys" : @[ @"test_featureA", @"test_featureB" ],
      @"activeRollouts" : rolloutsInfo
    };

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
  [super tearDown];
}

/// Test isFeatureEnabled public API works as expected.
- (void)testIsFeatureEnabled {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:@"Test enabledFeatureKeys public API works as expected."];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    FIRRemoteConfigFetchCompletion fetchCompletion =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
          XCTAssertNil(error);
          XCTAssertTrue([_configInstances[i] activateFetched]);
          XCTAssertTrue([_configInstances[i] isFeatureEnabledForKey:@"test_featureA"]);
          XCTAssertTrue([_configInstances[i] isFeatureEnabledForKey:@"test_featureB"]);
          XCTAssertFalse([_configInstances[i] isFeatureEnabledForKey:@"test_featureC"]);
          [expectations[i] fulfill];
        };
    [_configInstances[i] fetchWithExpirationDuration:43200 completionHandler:fetchCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectationTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

/// Test enabledFeatureKeys public API works as expected.
- (void)testEnabledFeatureKeys {
  NSMutableArray<XCTestExpectation *> *expectations =
      [[NSMutableArray alloc] initWithCapacity:RCNTestRCNumTotalInstances];
  for (int i = 0; i < RCNTestRCNumTotalInstances; i++) {
    expectations[i] =
        [self expectationWithDescription:@"Test enabledFeatureKeys public API works as expected."];
    XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusNoFetchYet);
    FIRRemoteConfigFetchCompletion fetchCompletion =
        ^void(FIRRemoteConfigFetchStatus status, NSError *error) {
          XCTAssertEqual(_configInstances[i].lastFetchStatus, FIRRemoteConfigFetchStatusSuccess);
          XCTAssertNil(error);
          XCTAssertTrue([_configInstances[i] activateFetched]);
          NSArray<NSString *> *enabledFeatures = [_configInstances[i] enabledFeatureKeys];
          XCTAssertNotNil(enabledFeatures);
          XCTAssertTrue([enabledFeatures containsObject:@"test_featureA"]);
          XCTAssertTrue([enabledFeatures containsObject:@"test_featureB"]);
          XCTAssertFalse([enabledFeatures containsObject:@"test_featureC"]);
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
  return
      [[FIROptions alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]]
                                                     pathForResource:@"SecondApp-GoogleService-Info"
                                                              ofType:@"plist"]];
}

@end
