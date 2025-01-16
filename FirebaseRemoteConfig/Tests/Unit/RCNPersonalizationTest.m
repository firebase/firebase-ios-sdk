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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

@import FirebaseRemoteConfig;

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"
#import "Interop/Analytics/Public/FIRAnalyticsInterop.h"

#define RCNExperimentTableKeyPayload "experiment_payload"
#define RCNExperimentTableKeyMetadata "experiment_metadata"
#define RCNExperimentTableKeyActivePayload "experiment_active_payload"
#define RCNRolloutTableKeyActiveMetadata "active_rollout_metadata"
#define RCNRolloutTableKeyFetchedMetadata "fetched_rollout_metadata"

typedef void (^FIRRemoteConfigFetchAndActivateCompletion)(
    FIRRemoteConfigFetchAndActivateStatus status, NSError *_Nullable error);

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

@import FirebaseRemoteConfig;

static NSString *const kAnalyticsOriginPersonalization = @"fp";

static NSString *const kExternalEvent = @"personalization_assignment";
static NSString *const kExternalRcParameterParam = @"arm_key";
static NSString *const kExternalArmValueParam = @"arm_value";
static NSString *const kPersonalizationId = @"personalizationId";
static NSString *const kExternalPersonalizationIdParam = @"personalization_id";
static NSString *const kArmIndex = @"armIndex";
static NSString *const kExternalArmIndexParam = @"arm_index";
static NSString *const kGroup = @"group";
static NSString *const kExternalGroupParam = @"group";

static NSString *const kInternalEvent = @"_fpc";
static NSString *const kChoiceId = @"choiceId";
static NSString *const kInternalChoiceIdParam = @"_fpid";

//@interface RCNConfigFetch (ForTest)
//- (NSURLSessionDataTask *)URLSessionDataTaskWithContent:(NSData *)content
//                                        fetchTypeHeader:(NSString *)fetchTypeHeader
//                                      completionHandler:(void (^)(NSData *data,
//                                                                  NSURLResponse *response,
//                                                                  NSError
//                                                                  *error))fetcherCompletion;
//
//- (void)fetchWithUserProperties:(NSDictionary *)userProperties
//                fetchTypeHeader:(NSString *)fetchTypeHeader
//              completionHandler:(FIRRemoteConfigFetchCompletion)completionHandler
//        updateCompletionHandler:(void (^)(FIRRemoteConfigFetchStatus status,
//                                          FIRRemoteConfigUpdate *update,
//                                          NSError *error))updateCompletionHandler;
//@end

@interface RCNPersonalizationTest : XCTestCase {
  NSDictionary *_configContainer;
  NSMutableArray<NSDictionary *> *_fakeLogs;
  id _analyticsMock;
  RCNPersonalization *_personalization;
  FIRRemoteConfig *_configInstance;
}
@end

@implementation RCNPersonalizationTest
- (void)setUp {
  [super setUp];

  _configContainer = @{
    RCNFetchResponseKeyEntries : @{
      @"key1" : [[FIRRemoteConfigValue alloc]
          initWithData:[@"value1" dataUsingEncoding:NSUTF8StringEncoding]
                source:FIRRemoteConfigSourceRemote],
      @"key2" : [[FIRRemoteConfigValue alloc]
          initWithData:[@"value2" dataUsingEncoding:NSUTF8StringEncoding]
                source:FIRRemoteConfigSourceRemote],
      @"key3" : [[FIRRemoteConfigValue alloc]
          initWithData:[@"value3" dataUsingEncoding:NSUTF8StringEncoding]
                source:FIRRemoteConfigSourceRemote]
    },
    RCNFetchResponseKeyPersonalizationMetadata : @{
      @"key1" : @{
        kPersonalizationId : @"p13n1",
        kArmIndex : @0,
        kChoiceId : @"id1",
        kGroup : @"BASELINE"
      },
      @"key2" :
          @{kPersonalizationId : @"p13n2", kArmIndex : @1, kChoiceId : @"id2", kGroup : @"P13N"}
    }
  };

  _fakeLogs = [[NSMutableArray alloc] init];
  _analyticsMock = OCMProtocolMock(@protocol(FIRAnalyticsInterop));
  OCMStub([_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                        name:[OCMArg isKindOfClass:[NSString class]]
                                  parameters:[OCMArg isKindOfClass:[NSDictionary class]]])
      .andDo(^(NSInvocation *invocation) {
        __unsafe_unretained NSDictionary *bundle;
        [invocation getArgument:&bundle atIndex:4];
        [self->_fakeLogs addObject:bundle];
      });

  _personalization = [[RCNPersonalization alloc] initWithAnalytics:_analyticsMock];

  // Always remove the database at the start of testing.
  NSString *DBPath = [RCNTestUtilities remoteConfigPathForTestDatabase];
  RCNConfigDBManager *DBManager = [[RCNConfigDBManager alloc] initWithDbPath:DBPath];

  RCNConfigContent *configContent = [[RCNConfigContent alloc] initWithDBManager:DBManager];

  // Create a mock FIRRemoteConfig instance.
  FIROptions *options = [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:test"
                                                    GCMSenderID:@"testSender"];
  options.APIKey = @"test API key";
  _configInstance = OCMPartialMock([[FIRRemoteConfig alloc] initWithAppName:@"testApp"
                                                                 FIROptions:options
                                                                  namespace:@"namespace"
                                                                  DBManager:DBManager
                                                              configContent:configContent
                                                                  analytics:_analyticsMock]);
  //  [_configInstance setValue:[RCNPersonalizationTest mockFetchRequest] forKey:@"_configFetch"];
}

- (void)tearDown {
  [super tearDown];
}

- (void)testNonPersonalizationKey {
  [_fakeLogs removeAllObjects];
  [_personalization logArmActiveWithRcParameter:@"key3" config:_configContainer];

  OCMVerify(never(),
            [_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                          name:[OCMArg checkWithBlock:^BOOL(NSString *value) {
                                            return [value isEqualToString:kExternalEvent] ||
                                                   [value isEqualToString:kInternalEvent];
                                          }]
                                    parameters:[OCMArg isKindOfClass:[NSDictionary class]]]);
  XCTAssertEqual([_fakeLogs count], 0);
}

- (void)testSinglePersonalizationKey {
  [_fakeLogs removeAllObjects];

  [_personalization logArmActiveWithRcParameter:@"key1" config:_configContainer];

  OCMVerify(times(2),
            [_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                          name:[OCMArg checkWithBlock:^BOOL(NSString *value) {
                                            return [value isEqualToString:kExternalEvent] ||
                                                   [value isEqualToString:kInternalEvent];
                                          }]
                                    parameters:[OCMArg isKindOfClass:[NSDictionary class]]]);
  XCTAssertEqual([_fakeLogs count], 2);

  NSDictionary *logParams = @{
    kExternalRcParameterParam : @"key1",
    kExternalArmValueParam : @"value1",
    kExternalPersonalizationIdParam : @"p13n1",
    kExternalArmIndexParam : @0,
    kExternalGroupParam : @"BASELINE"
  };
  XCTAssertEqualObjects(_fakeLogs[0], logParams);

  NSDictionary *internalLogParams = @{kInternalChoiceIdParam : @"id1"};
  XCTAssertEqualObjects(_fakeLogs[1], internalLogParams);
}

- (void)testMultiplePersonalizationKeys {
  [_fakeLogs removeAllObjects];

  [_personalization logArmActiveWithRcParameter:@"key1" config:_configContainer];
  [_personalization logArmActiveWithRcParameter:@"key2" config:_configContainer];
  [_personalization logArmActiveWithRcParameter:@"key1" config:_configContainer];

  OCMVerify(times(4),
            [_analyticsMock logEventWithOrigin:kAnalyticsOriginPersonalization
                                          name:[OCMArg checkWithBlock:^BOOL(NSString *value) {
                                            return [value isEqualToString:kExternalEvent] ||
                                                   [value isEqualToString:kInternalEvent];
                                          }]
                                    parameters:[OCMArg isKindOfClass:[NSDictionary class]]]);
  XCTAssertEqual([_fakeLogs count], 4);

  NSDictionary *logParams1 = @{
    kExternalRcParameterParam : @"key1",
    kExternalArmValueParam : @"value1",
    kExternalPersonalizationIdParam : @"p13n1",
    kExternalArmIndexParam : @0,
    kExternalGroupParam : @"BASELINE"
  };
  XCTAssertEqualObjects(_fakeLogs[0], logParams1);

  NSDictionary *internalLogParams1 = @{kInternalChoiceIdParam : @"id1"};
  XCTAssertEqualObjects(_fakeLogs[1], internalLogParams1);

  NSDictionary *logParams2 = @{
    kExternalRcParameterParam : @"key2",
    kExternalArmValueParam : @"value2",
    kExternalPersonalizationIdParam : @"p13n2",
    kExternalArmIndexParam : @1,
    kExternalGroupParam : @"P13N"
  };
  XCTAssertEqualObjects(_fakeLogs[2], logParams2);

  NSDictionary *internalLogParams2 = @{kInternalChoiceIdParam : @"id2"};
  XCTAssertEqualObjects(_fakeLogs[3], internalLogParams2);
}

// Skip very slow test while iterating

- (void)SKIPtestRemoteConfigIntegration {
  [_fakeLogs removeAllObjects];

  FIRRemoteConfigFetchAndActivateCompletion fetchAndActivateCompletion =
      ^void(FIRRemoteConfigFetchAndActivateStatus status, NSError *error) {
        OCMVerify(times(4), [self->_analyticsMock
                                logEventWithOrigin:kAnalyticsOriginPersonalization
                                              name:[OCMArg checkWithBlock:^BOOL(NSString *value) {
                                                return [value isEqualToString:kExternalEvent] ||
                                                       [value isEqualToString:kInternalEvent];
                                              }]
                                        parameters:[OCMArg isKindOfClass:[NSDictionary class]]]);
        XCTAssertEqual([self->_fakeLogs count], 4);

        NSDictionary *logParams1 = @{
          kExternalRcParameterParam : @"key1",
          kExternalArmValueParam : @"value1",
          kExternalPersonalizationIdParam : @"p13n1",
          kExternalArmIndexParam : @0,
          kExternalGroupParam : @"BASELINE"
        };
        XCTAssertEqualObjects(self->_fakeLogs[0], logParams1);

        NSDictionary *internalLogParams1 = @{kInternalChoiceIdParam : @"id1"};
        XCTAssertEqualObjects(self->_fakeLogs[1], internalLogParams1);

        NSDictionary *logParams2 = @{
          kExternalRcParameterParam : @"key1",
          kExternalArmValueParam : @"value1",
          kExternalPersonalizationIdParam : @"p13n1",
          kExternalArmIndexParam : @0,
          kExternalGroupParam : @"BASELINE"
        };
        XCTAssertEqualObjects(self->_fakeLogs[2], logParams2);

        NSDictionary *internalLogParams2 = @{kInternalChoiceIdParam : @"id2"};
        XCTAssertEqualObjects(self->_fakeLogs[3], internalLogParams2);
      };

  [_configInstance fetchAndActivateWithCompletionHandler:fetchAndActivateCompletion];
  [_configInstance configValueForKey:@"key1"];
  [_configInstance configValueForKey:@"key2"];
}

//+ (id)mockFetchRequest {
//  id configFetch = OCMClassMock([RCNConfigFetch class]);
//  OCMStub([configFetch fetchConfigWithExpirationDuration:0 completionHandler:OCMOCK_ANY])
//      .ignoringNonObjectArgs()
//      .andDo(^(NSInvocation *invocation) {
//        __unsafe_unretained FIRRemoteConfigFetchCompletion handler;
//        [invocation getArgument:&handler atIndex:3];
//        [configFetch fetchWithUserProperties:[[NSDictionary alloc] init]
//                             fetchTypeHeader:@"Base/1"
//                           completionHandler:handler
//                     updateCompletionHandler:nil];
//      });
//  OCMExpect([configFetch
//                URLSessionDataTaskWithContent:[OCMArg any]
//                              fetchTypeHeader:@"Base/1"
//                            completionHandler:[RCNPersonalizationTest mockResponseHandler]])
//      .andReturn(nil);
//  return configFetch;
//}

//+ (id)mockResponseHandler {
//  NSDictionary *response = @{
//    RCNFetchResponseKeyState : RCNFetchResponseKeyStateUpdate,
//    RCNFetchResponseKeyEntries : @{@"key1" : @"value1", @"key2" : @"value2", @"key3" : @"value3"},
//    RCNFetchResponseKeyPersonalizationMetadata : @{
//      @"key1" : @{
//        kPersonalizationId : @"p13n1",
//        kArmIndex : @0,
//        kChoiceId : @"id1",
//        kGroup : @"BASELINE"
//      },
//      @"key2" :
//          @{kPersonalizationId : @"p13n2", kArmIndex : @1, kChoiceId : @"id2", kGroup : @"P13N"}
//    }
//
//  };
//  return [OCMArg invokeBlockWithArgs:[NSJSONSerialization dataWithJSONObject:response
//                                                                     options:0
//                                                                       error:nil],
//                                     [[NSHTTPURLResponse alloc]
//                                          initWithURL:[NSURL
//                                          URLWithString:@"https://firebase.com"]
//                                           statusCode:200
//                                          HTTPVersion:nil
//                                         headerFields:@{@"etag" : @"etag1"}],
//                                     [NSNull null], nil];
//}

@end
