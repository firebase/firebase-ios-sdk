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

#import <sqlite3.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"
#import "FirebaseRemoteConfig/Sources/Private/RCNConfigSettings.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigConstants.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigContent.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDBManager.h"
#import "FirebaseRemoteConfig/Sources/RCNConfigDefines.h"
#import "FirebaseRemoteConfig/Tests/Unit/RCNTestUtilities.h"

@interface RCNConfigDBManager (Test)
- (void)removeDatabaseOnDatabaseQueueAtPath:(NSString *)path;
- (void)insertExperimentTableWithKey:(NSString *)key
                               value:(NSData *)serializedValue
                   completionHandler:(RCNDBCompletion)handler;
- (void)deleteExperimentTableForKey:(NSString *)key;
- (void)createOrOpenDatabase;
@end

@interface RCNConfigDBManagerTest : XCTestCase {
  NSString *_DBPath;
}
@property(nonatomic, strong) RCNConfigDBManager *DBManager;
@property(nonatomic, assign) NSTimeInterval expectionTimeout;
@end

@implementation RCNConfigDBManagerTest

- (void)setUp {
  [super setUp];
  // always remove the database at the start of testing
  _DBPath = [RCNTestUtilities remoteConfigPathForTestDatabase];

  _expectionTimeout = 10.0;
  id classMock = OCMClassMock([RCNConfigDBManager class]);
  OCMStub([classMock remoteConfigPathForDatabase]).andReturn(_DBPath);
  _DBManager = [[RCNConfigDBManager alloc] init];
}

- (void)tearDown {
  // Causes crash if main thread exits before the RCNConfigDB queue cleans up
  //  [_DBManager removeDatabaseOnDatabaseQueueAtPath:_DBPath];
}

- (void)testV1NamespaceMigrationToV2Namespace {
  // Write v1 namespace.
  XCTestExpectation *loadConfigContentExpectation =
      [self expectationWithDescription:@"test v1 namespace migration to v2 namespace"];
  NSString *namespace_p = @"testNamespace";
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  __block int count = 0;
  for (int i = 0; i <= 100; ++i) {
    // Check namespace is updated after database write is completed.
    RCNDBCompletion insertCompletion = ^void(BOOL success,
                                             NSDictionary<NSString *, NSString *> *result) {
      count++;
      XCTAssertTrue(success);
      if (count == 100) {
        // Migrate to the new namespace.
        [self->_DBManager createOrOpenDatabase];
        [self->_DBManager
            loadMainWithBundleIdentifier:bundleIdentifier
                       completionHandler:^(
                           BOOL loadSuccess,
                           NSDictionary<NSString *, NSDictionary<NSString *, id> *> *fetchedConfig,
                           NSDictionary<NSString *, NSDictionary<NSString *, id> *> *activeConfig,
                           NSDictionary<NSString *, NSDictionary<NSString *, id> *>
                               *defaultConfig) {
                         XCTAssertTrue(loadSuccess);
                         NSString *fullyQualifiedNamespace =
                             [NSString stringWithFormat:@"%@:%@", namespace_p, kFIRDefaultAppName];
                         XCTAssertNotNil(fetchedConfig[fullyQualifiedNamespace]);
                         XCTAssertEqual([fetchedConfig[fullyQualifiedNamespace] count], 101U);
                         XCTAssertEqual([fetchedConfig[namespace_p] count], 0);
                         if (loadSuccess) {
                           [loadConfigContentExpectation fulfill];
                         }
                       }];
      }
    };
    NSString *value = [NSString stringWithFormat:@"value%d", i];
    NSString *key = [NSString stringWithFormat:@"key%d", i];
    NSArray<id> *values =
        @[ bundleIdentifier, namespace_p, key, [value dataUsingEncoding:NSUTF8StringEncoding] ];
    [_DBManager insertMainTableWithValues:values
                               fromSource:RCNDBSourceFetched
                        completionHandler:insertCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectionTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testWriteAndLoadMainTableResult {
  XCTestExpectation *loadConfigContentExpectation =
      [self expectationWithDescription:@"Write and read metadata in database serializedly"];
  NSString *namespace_p = @"namespace_1";
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  __block int count = 0;
  for (int i = 0; i <= 100; ++i) {
    // check DB write correctly
    RCNDBCompletion insertCompletion = ^void(BOOL success, NSDictionary *result) {
      count++;
      XCTAssertTrue(success);
      if (count == 100) {
        // check DB read correctly
        [self->_DBManager loadMainWithBundleIdentifier:bundleIdentifier
                                     completionHandler:^(BOOL success, NSDictionary *fetchedConfig,
                                                         NSDictionary *activeConfig,
                                                         NSDictionary *defaultConfig) {
                                       NSMutableDictionary *res = [fetchedConfig mutableCopy];
                                       XCTAssertTrue(success);
                                       FIRRemoteConfigValue *value = res[namespace_p][@"key100"];
                                       XCTAssertEqualObjects(value.stringValue, @"value100");
                                       if (success) {
                                         [loadConfigContentExpectation fulfill];
                                       }
                                     }];
      }
    };
    NSString *value = [NSString stringWithFormat:@"value%d", i];
    NSString *key = [NSString stringWithFormat:@"key%d", i];
    NSArray *values =
        @[ bundleIdentifier, namespace_p, key, [value dataUsingEncoding:NSUTF8StringEncoding] ];
    [_DBManager insertMainTableWithValues:values
                               fromSource:RCNDBSourceFetched
                        completionHandler:insertCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectionTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testWriteAndLoadInternalMetadataResult {
  XCTestExpectation *loadConfigContentExpectation = [self
      expectationWithDescription:@"Write and read internal metadata in database successfully"];
  __block int count = 0;
  for (int i = 0; i <= 100; ++i) {
    // check DB write correctly
    RCNDBCompletion insertCompletion = ^void(BOOL success, NSDictionary *result) {
      count++;
      XCTAssertTrue(success);
      if (count == 100) {
        // check DB read correctly
        NSDictionary *result = [self->_DBManager loadInternalMetadataTable];
        NSString *stringValue = [[NSString alloc] initWithData:result[@"key100"]
                                                      encoding:NSUTF8StringEncoding];
        XCTAssertEqualObjects(stringValue, @"value100");
        if (success) {
          [loadConfigContentExpectation fulfill];
        }
      }
    };
    NSString *value = [NSString stringWithFormat:@"value%d", i];
    NSString *key = [NSString stringWithFormat:@"key%d", i];

    NSArray *values = @[ key, [value dataUsingEncoding:NSUTF8StringEncoding] ];
    [_DBManager insertInternalMetadataTableWithValues:values completionHandler:insertCompletion];
  }

  [self waitForExpectationsWithTimeout:_expectionTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testWriteAndLoadMetadataResult {
  XCTestExpectation *writeAndLoadMetadataExpectation =
      [self expectationWithDescription:@"Write and load metadata in database successfully"];
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  NSString *namespace = @"test_namespace";
  NSTimeInterval lastFetchTimestamp = [NSDate date].timeIntervalSince1970;

  NSDictionary *deviceContext =
      @{@"app_version" : @"1.0.1", @"app_build" : @"1.0.1.11", @"os_version" : @"iOS9.1"};
  NSDictionary *syncedDBCustomVariables = @{@"user_level" : @15, @"user_experiences" : @"2468"};
  NSArray *successFetchTimes = @[];
  NSTimeInterval now = [NSDate date].timeIntervalSince1970;
  NSArray *failureFetchTimes =
      @[ [NSNumber numberWithDouble:now - 200], [NSNumber numberWithDouble:now] ];

  // serialize objects
  NSError *error;
  NSData *serializedAppContext = [NSJSONSerialization dataWithJSONObject:syncedDBCustomVariables
                                                                 options:NSJSONWritingPrettyPrinted
                                                                   error:&error];
  NSData *serializedDeviceContext =
      [NSJSONSerialization dataWithJSONObject:deviceContext
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  NSData *serializedDigestPerNamespace =
      [NSJSONSerialization dataWithJSONObject:@{} options:NSJSONWritingPrettyPrinted error:&error];
  NSData *serializedSuccessTime = [NSJSONSerialization dataWithJSONObject:successFetchTimes
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
  NSData *serializedFailureTime = [NSJSONSerialization dataWithJSONObject:failureFetchTimes
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
  NSDictionary *columnNameToValue = @{
    RCNKeyBundleIdentifier : bundleIdentifier,
    RCNKeyNamespace : namespace,
    RCNKeyFetchTime : @(lastFetchTimestamp),
    RCNKeyDigestPerNamespace : serializedDigestPerNamespace,
    RCNKeyDeviceContext : serializedDeviceContext,
    RCNKeyAppContext : serializedAppContext,
    RCNKeySuccessFetchTime : serializedSuccessTime,
    RCNKeyFailureFetchTime : serializedFailureTime,
    RCNKeyLastFetchStatus : @(FIRRemoteConfigFetchStatusSuccess),
    RCNKeyLastFetchError : @(FIRRemoteConfigErrorUnknown),
    RCNKeyLastApplyTime : @(now - 100),
    RCNKeyLastSetDefaultsTime : @(now - 200)
  };

  RCNDBCompletion completion = ^(BOOL success, NSDictionary *result1) {
    NSDictionary *result = [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier
                                                                    namespace:namespace];
    XCTAssertNotNil(result);
    XCTAssertEqualObjects(result[RCNKeyBundleIdentifier], bundleIdentifier);
    XCTAssertEqual([result[RCNKeyFetchTime] doubleValue], lastFetchTimestamp);
    XCTAssertEqualObjects([result[RCNKeyDigestPerNamespace] copy], @{});
    XCTAssertEqualObjects([result[RCNKeyDeviceContext] copy], deviceContext);
    XCTAssertEqualObjects([result[RCNKeyAppContext] copy], syncedDBCustomVariables);
    XCTAssertEqualObjects([result[RCNKeySuccessFetchTime] copy], successFetchTimes);
    // TODO(chliang): Fix the flakiness caused by the commented out test
    // XCTAssertTrue([[result[RCNKeyFailureFetchTime] copy] isEqualToArray:failureFetchTimes]);
    XCTAssertEqual([result[RCNKeyLastFetchStatus] intValue],
                   (int)FIRRemoteConfigFetchStatusSuccess);
    XCTAssertEqual([result[RCNKeyLastFetchError] intValue], (int)FIRRemoteConfigErrorUnknown);
    XCTAssertEqual([result[RCNKeyLastApplyTime] doubleValue], now - 100);
    XCTAssertEqual([result[RCNKeyLastSetDefaultsTime] doubleValue], now - 200);
    [writeAndLoadMetadataExpectation fulfill];
  };

  [_DBManager insertMetadataTableWithValues:columnNameToValue completionHandler:completion];
  [self waitForExpectationsWithTimeout:_expectionTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testWriteAndLoadMetadataForMultipleNamespaces {
  XCTestExpectation *writeAndLoadMetadataForMultipleNamespacesExpectation =
      [self expectationWithDescription:@"Metadata is stored and read based on namespace"];
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  NSDictionary *deviceContext = @{};
  NSDictionary *syncedDBCustomVariables = @{};
  NSError *error;
  NSData *serializedAppContext = [NSJSONSerialization dataWithJSONObject:syncedDBCustomVariables
                                                                 options:NSJSONWritingPrettyPrinted
                                                                   error:&error];
  NSData *serializedDeviceContext =
      [NSJSONSerialization dataWithJSONObject:deviceContext
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  NSData *serializedDigestPerNamespace =
      [NSJSONSerialization dataWithJSONObject:@{} options:NSJSONWritingPrettyPrinted error:&error];
  NSData *serializedSuccessTime = [NSJSONSerialization dataWithJSONObject:@[]
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
  NSData *serializedFailureTime = [NSJSONSerialization dataWithJSONObject:@[]
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];

  // Metadata for first namespace
  NSString *namespace = @"test_namespace";
  double lastApplyTime = 100;
  double lastSetDefaultsTime = 200;
  NSDictionary *valuesForNamespace = @{
    RCNKeyBundleIdentifier : bundleIdentifier,
    RCNKeyNamespace : namespace,
    RCNKeyFetchTime : @(0),
    RCNKeyDigestPerNamespace : serializedDigestPerNamespace,
    RCNKeyDeviceContext : serializedDeviceContext,
    RCNKeyAppContext : serializedAppContext,
    RCNKeySuccessFetchTime : serializedSuccessTime,
    RCNKeyFailureFetchTime : serializedFailureTime,
    RCNKeyLastFetchStatus : @(FIRRemoteConfigFetchStatusSuccess),
    RCNKeyLastFetchError : @(FIRRemoteConfigErrorUnknown),
    RCNKeyLastApplyTime : @(lastApplyTime),
    RCNKeyLastSetDefaultsTime : @(lastSetDefaultsTime)
  };

  // Metadata for second namespace
  NSString *namespace2 = @"test_namespace_2";
  double lastApplyTime2 = 300;
  double lastSetDefaultsTime2 = 400;
  NSDictionary *valuesForNamespace2 = @{
    RCNKeyBundleIdentifier : bundleIdentifier,
    RCNKeyNamespace : namespace2,
    RCNKeyFetchTime : @(0),
    RCNKeyDigestPerNamespace : serializedDigestPerNamespace,
    RCNKeyDeviceContext : serializedDeviceContext,
    RCNKeyAppContext : serializedAppContext,
    RCNKeySuccessFetchTime : serializedSuccessTime,
    RCNKeyFailureFetchTime : serializedFailureTime,
    RCNKeyLastFetchStatus : @(FIRRemoteConfigFetchStatusSuccess),
    RCNKeyLastFetchError : @(FIRRemoteConfigErrorUnknown),
    RCNKeyLastApplyTime : @(lastApplyTime2),
    RCNKeyLastSetDefaultsTime : @(lastSetDefaultsTime2)
  };

  RCNDBCompletion insertMetadataCompletion = ^void(BOOL success, NSDictionary *result) {
    XCTAssertTrue(success);

    // Load metadata for both namespaces and verify they retain their separate values
    NSDictionary *resultForNamespace =
        [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier namespace:namespace];
    NSDictionary *resultForNamespace2 =
        [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier namespace:namespace2];

    XCTAssertNotNil(resultForNamespace);
    XCTAssertEqual([resultForNamespace[RCNKeyLastApplyTime] doubleValue], lastApplyTime);
    XCTAssertEqual([resultForNamespace[RCNKeyLastSetDefaultsTime] doubleValue],
                   lastSetDefaultsTime);

    XCTAssertNotNil(resultForNamespace2);
    XCTAssertEqual([resultForNamespace2[RCNKeyLastApplyTime] doubleValue], lastApplyTime2);
    XCTAssertEqual([resultForNamespace2[RCNKeyLastSetDefaultsTime] doubleValue],
                   lastSetDefaultsTime2);
    [writeAndLoadMetadataForMultipleNamespacesExpectation fulfill];
  };

  // Write metadata for first namespace
  [_DBManager insertMetadataTableWithValues:valuesForNamespace
                          completionHandler:^(BOOL success, NSDictionary *result1) {
                            XCTAssertTrue(success);
                            // Write metadata for second namespace
                            [self->_DBManager
                                insertMetadataTableWithValues:valuesForNamespace2
                                            completionHandler:insertMetadataCompletion];
                          }];
  [self waitForExpectationsWithTimeout:_expectionTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

// Create a key each for two namespaces, delete it from one namespace, read both namespaces.
- (void)testDeleteParamAndLoadMainTable {
  XCTestExpectation *namespaceDeleteExpectation =
      [self expectationWithDescription:@"Contents of 'namespace_delete' should be deleted."];
  XCTestExpectation *namespaceKeepExpectation =
      [self expectationWithDescription:@"Write a key to namespace_keep and read back again."];
  NSString *namespaceToDelete = @"namespace_delete";
  NSString *namespaceToKeep = @"namespace_keep";
  NSString *bundleIdentifier = @"testBundleID";

  // Write something to the database for both namespaces.
  // Completion handler for the write to namespace_delete namespace.
  RCNDBCompletion insertNamespace1Completion = ^void(BOOL success, NSDictionary *result) {
    XCTAssertTrue(success);

    // Delete the key for given namespace.
    [self->_DBManager deleteRecordFromMainTableWithNamespace:namespaceToDelete
                                            bundleIdentifier:bundleIdentifier
                                                  fromSource:RCNDBSourceActive];

    // Read from the database and verify expected values.
    [self->_DBManager
        loadMainWithBundleIdentifier:bundleIdentifier
                   completionHandler:^(BOOL success, NSDictionary *fetchedConfig,
                                       NSDictionary *activeConfig, NSDictionary *defaultConfig) {
                     NSMutableDictionary *res = [activeConfig mutableCopy];
                     XCTAssertTrue(success);
                     FIRRemoteConfigValue *value = res[namespaceToDelete][@"keyToDelete"];
                     XCTAssertNil(value);

                     FIRRemoteConfigValue *value2 = res[namespaceToKeep][@"keyToRetain"];
                     XCTAssertTrue([value2.stringValue isEqualToString:@"valueToRetain"]);

                     [namespaceDeleteExpectation fulfill];
                   }];
  };

  // Insert a key into the second namespace.
  RCNDBCompletion insertNamespace2Completion = ^void(BOOL success, NSDictionary *result) {
    XCTAssertTrue(success);

    // Ensure DB read succeeds.
    [self->_DBManager
        loadMainWithBundleIdentifier:bundleIdentifier
                   completionHandler:^(BOOL success, NSDictionary *fetchedConfig,
                                       NSDictionary *activeConfig, NSDictionary *defaultConfig) {
                     NSMutableDictionary *res = [activeConfig mutableCopy];
                     XCTAssertTrue(success);
                     FIRRemoteConfigValue *value2 = res[namespaceToKeep][@"keyToRetain"];
                     XCTAssertTrue([value2.stringValue isEqualToString:@"valueToRetain"]);

                     [namespaceKeepExpectation fulfill];
                   }];
  };
  // We will delete this key after storing in the database.
  NSString *valueToDelete = @"valueToDelete";
  NSString *keyToDelete = @"keyToDelete";
  NSArray *items = @[
    bundleIdentifier, namespaceToDelete, keyToDelete,
    [valueToDelete dataUsingEncoding:NSUTF8StringEncoding]
  ];
  [_DBManager insertMainTableWithValues:items
                             fromSource:RCNDBSourceActive
                      completionHandler:insertNamespace1Completion];

  // This key value will be retained.
  NSString *valueToRetain = @"valueToRetain";
  NSString *keyToRetain = @"keyToRetain";
  NSArray *items2 = @[
    bundleIdentifier, namespaceToKeep, keyToRetain,
    [valueToRetain dataUsingEncoding:NSUTF8StringEncoding]
  ];
  [_DBManager insertMainTableWithValues:items2
                             fromSource:RCNDBSourceActive
                      completionHandler:insertNamespace2Completion];

  [self waitForExpectationsWithTimeout:_expectionTimeout
                               handler:^(NSError *error) {
                                 XCTAssertNil(error);
                               }];
}

- (void)testWriteAndLoadExperiments {
  XCTestExpectation *updateAndLoadExperimentExpectation =
      [self expectationWithDescription:@"Update and load experiment in database successfully"];

  NSError *error;
  NSArray *payload2 = @[ @"ab", @"cd" ];
  NSData *payloadData2 = [NSJSONSerialization dataWithJSONObject:payload2
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
  NSDictionary *payload3 =
      @{@"experiment_ID" : @"35667", @"experiment_activate_name" : @"activate_game"};
  NSData *payloadData3 = [NSJSONSerialization dataWithJSONObject:payload3
                                                         options:NSJSONWritingPrettyPrinted
                                                           error:&error];
  NSArray *payloads = @[ [[NSData alloc] init], payloadData2, payloadData3 ];

  RCNDBCompletion writePayloadCompletion = ^(BOOL success, NSDictionary *result) {
    NSDictionary *metadata =
        @{@"last_known_start_time" : @(-11), @"experiment_new_metadata" : @"wonderful"};
    XCTAssertTrue(success);
    RCNDBCompletion writeMetadataCompletion = ^(BOOL success, NSDictionary *result) {
      XCTAssertTrue(success);
      RCNDBCompletion readCompletion = ^(BOOL success, NSDictionary *experimentResults) {
        XCTAssertTrue(success);
        XCTAssertNotNil(experimentResults[@RCNExperimentTableKeyPayload]);
        XCTAssertEqualObjects(payloads, experimentResults[@RCNExperimentTableKeyPayload]);

        XCTAssertNotNil(experimentResults[@RCNExperimentTableKeyMetadata]);
        XCTAssertEqualWithAccuracy(
            -11,
            [experimentResults[@RCNExperimentTableKeyMetadata][@"last_known_start_time"]
                doubleValue],
            1.0);
        XCTAssertEqualObjects(
            @"wonderful",
            experimentResults[@RCNExperimentTableKeyMetadata][@"experiment_new_metadata"]);
        [updateAndLoadExperimentExpectation fulfill];
      };
      [self->_DBManager loadExperimentWithCompletionHandler:readCompletion];
    };

    NSError *error;
    XCTAssertTrue([NSJSONSerialization isValidJSONObject:metadata]);
    NSData *serializedMetadata = [NSJSONSerialization dataWithJSONObject:metadata
                                                                 options:NSJSONWritingPrettyPrinted
                                                                   error:&error];

    [self->_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyMetadata
                                             value:serializedMetadata
                                 completionHandler:writeMetadataCompletion];
  };
  [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyPayload
                                     value:[[NSData alloc] init]
                         completionHandler:nil];
  [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyPayload
                                     value:payloadData2
                         completionHandler:nil];
  [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyPayload
                                     value:payloadData3
                         completionHandler:writePayloadCompletion];

  [self waitForExpectationsWithTimeout:_expectionTimeout handler:nil];
}

- (void)testWriteAndLoadMetadataMultipleTimes {
  XCTestExpectation *updateAndLoadMetadataExpectation = [self
      expectationWithDescription:@"Update and load experiment metadata in database successfully"];

  RCNDBCompletion readCompletion = ^(BOOL success, NSDictionary *experimentResults) {
    XCTAssertTrue(success);
    XCTAssertNotNil(experimentResults[@RCNExperimentTableKeyPayload]);
    XCTAssertNotNil(experimentResults[@RCNExperimentTableKeyMetadata]);
    XCTAssertEqualWithAccuracy(
        12345678,
        [experimentResults[@RCNExperimentTableKeyMetadata][@"last_known_start_time"] doubleValue],
        1.0);
    XCTAssertEqualObjects(
        @"wonderful",
        experimentResults[@RCNExperimentTableKeyMetadata][@"experiment_new_metadata"]);

    [updateAndLoadMetadataExpectation fulfill];
  };
  NSDictionary *metadata =
      @{@"last_known_start_time" : @(-11), @"experiment_new_metadata" : @"wonderful"};
  NSError *error;
  XCTAssertTrue([NSJSONSerialization isValidJSONObject:metadata]);
  NSData *serializedMetadata = [NSJSONSerialization dataWithJSONObject:metadata
                                                               options:NSJSONWritingPrettyPrinted
                                                                 error:&error];

  [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyMetadata
                                     value:serializedMetadata
                         completionHandler:nil];

  metadata = @{@"last_known_start_time" : @(12345678), @"experiment_new_metadata" : @"wonderful"};
  XCTAssertTrue([NSJSONSerialization isValidJSONObject:metadata]);
  serializedMetadata = [NSJSONSerialization dataWithJSONObject:metadata
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];

  [_DBManager insertExperimentTableWithKey:@RCNExperimentTableKeyMetadata
                                     value:serializedMetadata
                         completionHandler:nil];
  [_DBManager loadExperimentWithCompletionHandler:readCompletion];

  [self waitForExpectationsWithTimeout:_expectionTimeout handler:nil];
}

- (void)testUpdateAndloadLastFetchStatus {
  XCTestExpectation *updateAndLoadMetadataExpectation = [self
      expectationWithDescription:@"Update and load last fetch status in database successfully."];
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  NSString *namespace = @"test_namespace";

  // Metadata row must exist before update
  RCNDBCompletion createMetadataCompletion = ^(BOOL success, NSDictionary *createResult) {
    NSDictionary *result = [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier
                                                                    namespace:namespace];
    XCTAssertTrue(success);
    XCTAssertNotNil(result);
    XCTAssertEqual([result[RCNKeyLastFetchStatus] intValue],
                   (int)FIRRemoteConfigFetchStatusSuccess);
    XCTAssertEqual([result[RCNKeyLastFetchError] intValue], (int)FIRRemoteConfigErrorUnknown);

    RCNDBCompletion updateMetadataCompletion = ^(BOOL success, NSDictionary *updateResult) {
      NSDictionary *result = [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier
                                                                      namespace:namespace];

      XCTAssertTrue(success);
      XCTAssertNotNil(result);
      XCTAssertEqual([result[RCNKeyLastFetchStatus] intValue],
                     (int)FIRRemoteConfigFetchStatusThrottled);
      XCTAssertEqual([result[RCNKeyLastFetchError] intValue], (int)FIRRemoteConfigErrorThrottled);
      [updateAndLoadMetadataExpectation fulfill];
    };
    // Update with throttle status.
    [self->_DBManager
        updateMetadataWithOption:RCNUpdateOptionFetchStatus
                       namespace:namespace
                          values:@[
                            @(FIRRemoteConfigFetchStatusThrottled), @(FIRRemoteConfigErrorThrottled)
                          ]
               completionHandler:updateMetadataCompletion];
  };

  [_DBManager insertMetadataTableWithValues:[self createSampleMetadata]
                          completionHandler:createMetadataCompletion];
  [self waitForExpectationsWithTimeout:_expectionTimeout handler:nil];
}

/// Tests that we can insert values in the database and can update them.
- (void)testInsertAndUpdateApplyTime {
  XCTestExpectation *updateAndLoadMetadataExpectation =
      [self expectationWithDescription:@"Update and load apply time in database successfully."];
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  NSString *namespace = @"test_namespace";
  NSTimeInterval lastApplyTimestamp = [NSDate date].timeIntervalSince1970;

  // Metadata row must exist before update
  RCNDBCompletion createMetadataCompletion = ^(BOOL success, NSDictionary *createResult) {
    XCTAssertTrue(success);
    // Read newly created metadata.
    NSDictionary *result = [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier
                                                                    namespace:namespace];
    XCTAssertNotNil(result);
    XCTAssertEqual([result[RCNKeyLastApplyTime] doubleValue], (double)100);
    RCNDBCompletion updateMetadataCompletion = ^(BOOL success, NSDictionary *updateResult) {
      NSDictionary *result = [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier
                                                                      namespace:namespace];

      XCTAssertTrue(success);
      XCTAssertNotNil(result);
      XCTAssertEqual([result[RCNKeyLastApplyTime] doubleValue], lastApplyTimestamp);
      [updateAndLoadMetadataExpectation fulfill];
    };
    // Update apply config timestamp.
    [self->_DBManager updateMetadataWithOption:RCNUpdateOptionApplyTime
                                     namespace:namespace
                                        values:@[ @(lastApplyTimestamp) ]
                             completionHandler:updateMetadataCompletion];
  };

  [_DBManager insertMetadataTableWithValues:[self createSampleMetadata]
                          completionHandler:createMetadataCompletion];
  [self waitForExpectationsWithTimeout:_expectionTimeout handler:nil];
}

- (void)testUpdateAndLoadSetDefaultsTime {
  XCTestExpectation *updateAndLoadMetadataExpectation = [self
      expectationWithDescription:@"Update and load set defaults time in database successfully."];
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  NSString *namespace = @"test_namespace";
  NSTimeInterval lastSetDefaultsTimestamp = [NSDate date].timeIntervalSince1970;

  // Metadata row must exist before update
  RCNDBCompletion createMetadataCompletion = ^(BOOL success, NSDictionary *createResult) {
    NSDictionary *result = [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier
                                                                    namespace:namespace];
    XCTAssertTrue(success);
    XCTAssertNotNil(result);
    XCTAssertEqual([result[RCNKeyLastSetDefaultsTime] doubleValue], (double)200);
    RCNDBCompletion updateMetadataCompletion = ^(BOOL success, NSDictionary *updateResult) {
      NSDictionary *result = [self->_DBManager loadMetadataWithBundleIdentifier:bundleIdentifier
                                                                      namespace:namespace];

      XCTAssertTrue(success);
      XCTAssertNotNil(result);
      XCTAssertEqual([result[RCNKeyLastSetDefaultsTime] doubleValue], lastSetDefaultsTimestamp);
      [updateAndLoadMetadataExpectation fulfill];
    };
    // Update setting default config timestamp.
    [self->_DBManager updateMetadataWithOption:RCNUpdateOptionDefaultTime
                                     namespace:namespace
                                        values:@[ @(lastSetDefaultsTimestamp) ]
                             completionHandler:updateMetadataCompletion];
  };

  [_DBManager insertMetadataTableWithValues:[self createSampleMetadata]
                          completionHandler:createMetadataCompletion];
  [self waitForExpectationsWithTimeout:_expectionTimeout handler:nil];
}

- (NSDictionary *)createSampleMetadata {
  NSString *bundleIdentifier = [NSBundle mainBundle].bundleIdentifier;
  NSString *namespace = @"test_namespace";

  NSDictionary *deviceContext = @{};
  NSDictionary *syncedDBCustomVariables = @{};
  NSArray *successFetchTimes = @[];
  NSArray *failureFetchTimes = @[];

  // serialize objects
  NSError *error;
  NSData *serializedAppContext = [NSJSONSerialization dataWithJSONObject:syncedDBCustomVariables
                                                                 options:NSJSONWritingPrettyPrinted
                                                                   error:&error];
  NSData *serializedDeviceContext =
      [NSJSONSerialization dataWithJSONObject:deviceContext
                                      options:NSJSONWritingPrettyPrinted
                                        error:&error];
  NSData *serializedDigestPerNamespace =
      [NSJSONSerialization dataWithJSONObject:@{} options:NSJSONWritingPrettyPrinted error:&error];
  NSData *serializedSuccessTime = [NSJSONSerialization dataWithJSONObject:successFetchTimes
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
  NSData *serializedFailureTime = [NSJSONSerialization dataWithJSONObject:failureFetchTimes
                                                                  options:NSJSONWritingPrettyPrinted
                                                                    error:&error];
  return @{
    RCNKeyBundleIdentifier : bundleIdentifier,
    RCNKeyNamespace : namespace,
    RCNKeyFetchTime : @(0),
    RCNKeyDigestPerNamespace : serializedDigestPerNamespace,
    RCNKeyDeviceContext : serializedDeviceContext,
    RCNKeyAppContext : serializedAppContext,
    RCNKeySuccessFetchTime : serializedSuccessTime,
    RCNKeyFailureFetchTime : serializedFailureTime,
    RCNKeyLastFetchStatus : @(FIRRemoteConfigFetchStatusSuccess),
    RCNKeyLastFetchError : @(FIRRemoteConfigErrorUnknown),
    RCNKeyLastApplyTime : @(100),
    RCNKeyLastSetDefaultsTime : @(200)
  };
}

@end
