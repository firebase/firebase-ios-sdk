// Copyright 2019 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockFileManager.h"

const NSString *FIRCLSTestSettingsActivated =
    @"{\"settings_version\":3,\"cache_duration\":60,\"features\":{\"collect_logged_exceptions\":"
    @"true,\"collect_reports\":true, \"collect_metric_kit\":true},"
    @"\"fabric\":{\"org_id\":\"010101000000111111111111\",\"bundle_id\":\"com.lets.test."
    @"crashlytics\"}}";

const NSString *FIRCLSTestSettingsInverse =
    @"{\"settings_version\":3,\"cache_duration\":12345,\"features\":{\"collect_logged_exceptions\":"
    @"false,\"collect_reports\":false, \"collect_metric_kit\":false},"
    @"\"fabric\":{\"org_id\":\"01e101a0000011b113115111\",\"bundle_id\":\"im.from.the.server\"},"
    @"\"session\":{\"log_buffer_size\":128000,\"max_chained_exception_depth\":32,\"max_complete_"
    @"sessions_count\":4,\"max_custom_exception_events\":1000,\"max_custom_key_value_pairs\":2000,"
    @"\"identifier_mask\":255}, \"on_demand_upload_rate_per_minute\":15.0, "
    @"\"on_demand_backoff_base\":3.0, \"on_demand_backoff_step_duration_seconds\":9}";

const NSString *FIRCLSTestSettingsCorrupted = @"{{{{ non_key: non\"value {}";

NSString *FIRCLSDefaultMockBuildInstanceID = @"12345abcdef";
NSString *FIRCLSDifferentMockBuildInstanceID = @"98765zyxwv";

NSString *FIRCLSDefaultMockAppDisplayVersion = @"1.2.3-beta.2";
NSString *FIRCLSDifferentMockAppDisplayVersion = @"1.2.3-beta.3";

NSString *FIRCLSDefaultMockAppBuildVersion = @"1024";
NSString *FIRCLSDifferentMockAppBuildVersion = @"2048";

NSString *const TestGoogleAppID = @"1:test:google:app:id";
NSString *const TestChangedGoogleAppID = @"2:changed:google:app:id";

@interface FIRCLSSettings (Testing)

@property(nonatomic, strong) NSDictionary<NSString *, id> *settingsDictionary;

- (instancetype)initWithFileManager:(FIRCLSFileManager *)fileManager
                         appIDModel:(FIRCLSApplicationIdentifierModel *)appIDModel
                            appInfo:(nonnull NSDictionary *)appInfo
                      deletionQueue:(dispatch_queue_t)deletionQueue;

@end

@interface FIRCLSSettingsTests : XCTestCase

@property(nonatomic, retain) FIRCLSMockFileManager *fileManager;
@property(nonatomic, retain) FABMockApplicationIdentifierModel *appIDModel;

@property(nonatomic, retain) FIRCLSSettings *settings;

@end

@implementation FIRCLSSettingsTests

- (void)setUp {
  [super setUp];
  _fileManager = [[FIRCLSMockFileManager alloc] init];

  _appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  _appIDModel.buildInstanceID = FIRCLSDefaultMockBuildInstanceID;
  _appIDModel.displayVersion = FIRCLSDefaultMockAppDisplayVersion;
  _appIDModel.buildVersion = FIRCLSDefaultMockAppBuildVersion;

  // Inject a higher priority queue for deletion operations to reduce flakes.
  _settings = [[FIRCLSSettings alloc]
      initWithFileManager:_fileManager
               appIDModel:_appIDModel
                  appInfo:[[NSDictionary alloc] init]
            deletionQueue:dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)];
}

- (void)testDefaultSettings {
  XCTAssertEqual(self.settings.isCacheExpired, YES);

  // Default to an hour
  XCTAssertEqual(self.settings.cacheDurationSeconds, 60 * 60);

  XCTAssertTrue(self.settings.collectReportsEnabled);
  XCTAssertTrue(self.settings.errorReportingEnabled);
  XCTAssertTrue(self.settings.customExceptionsEnabled);
  XCTAssertFalse(self.settings.metricKitCollectionEnabled);
  XCTAssertFalse(self.settings.machExceptionDefaultBehavior);

  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.logBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.maxCustomExceptions, 8);
  XCTAssertEqual(self.settings.maxCustomKeys, 64);
  XCTAssertEqual(self.settings.onDemandUploadRate, 10);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 1.5);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 6);
}

- (BOOL)writeSettings:(const NSString *)settings error:(NSError **)error {
  return [self writeSettings:settings error:error isCacheKey:NO];
}

- (BOOL)writeSettings:(const NSString *)settings
                error:(NSError **)error
           isCacheKey:(BOOL)isCacheKey {
  NSString *path = _fileManager.settingsFilePath;

  if (isCacheKey) {
    path = _fileManager.settingsCacheKeyPath;
  }

  return [self.fileManager createFileAtPath:path
                                   contents:[settings dataUsingEncoding:NSUTF8StringEncoding]
                                 attributes:nil];
}

- (void)cacheSettingsWithGoogleAppID:(NSString *)googleAppID
                    currentTimestamp:(NSTimeInterval)currentTimestamp
                 expectedRemoveCount:(NSInteger)expectedRemoveCount {
  self.fileManager.removeExpectation = [[XCTestExpectation alloc]
      initWithDescription:@"FIRCLSMockFileManager.removeExpectation.cache"];
  self.fileManager.removeCount = 0;
  self.fileManager.expectedRemoveCount = expectedRemoveCount;

  [self.settings cacheSettingsWithGoogleAppID:googleAppID currentTimestamp:currentTimestamp];

  [self waitForExpectations:@[ self.fileManager.removeExpectation ] timeout:5.0];
}

- (void)reloadFromCacheWithGoogleAppID:(NSString *)googleAppID
                      currentTimestamp:(NSTimeInterval)currentTimestamp
                   expectedRemoveCount:(NSInteger)expectedRemoveCount {
  self.fileManager.removeExpectation = [[XCTestExpectation alloc]
      initWithDescription:@"FIRCLSMockFileManager.removeExpectation.reload"];
  self.fileManager.removeCount = 0;
  self.fileManager.expectedRemoveCount = expectedRemoveCount;

  [self.settings reloadFromCacheWithGoogleAppID:googleAppID currentTimestamp:currentTimestamp];

  [self waitForExpectations:@[ self.fileManager.removeExpectation ] timeout:5.0];
}

- (void)testActivatedSettingsCached {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsActivated error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 60);

  XCTAssertTrue(self.settings.collectReportsEnabled);
  XCTAssertTrue(self.settings.errorReportingEnabled);
  XCTAssertTrue(self.settings.customExceptionsEnabled);
  XCTAssertTrue(self.settings.metricKitCollectionEnabled);

  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.logBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.maxCustomExceptions, 8);
  XCTAssertEqual(self.settings.maxCustomKeys, 64);
  XCTAssertEqual(self.settings.onDemandUploadRate, 10);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 1.5);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 6);
}

- (void)testInverseDefaultSettingsCached {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 12345);

  XCTAssertFalse(self.settings.collectReportsEnabled);
  XCTAssertFalse(self.settings.errorReportingEnabled);
  XCTAssertFalse(self.settings.customExceptionsEnabled);
  XCTAssertFalse(self.settings.metricKitCollectionEnabled);

  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);
  XCTAssertEqual(self.settings.logBufferSize, 128000);
  XCTAssertEqual(self.settings.maxCustomExceptions, 1000);
  XCTAssertEqual(self.settings.maxCustomKeys, 2000);
  XCTAssertEqual(self.settings.onDemandUploadRate, 15);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 3);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 9);
}

- (void)testCacheExpiredFromTTL {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsActivated error:&error];
  XCTAssertNil(error, "%@", error);

  // 1 delete for clearing the cache key, plus 2 for the deletes from reloading and clearing the
  // cache and cache key
  self.fileManager.expectedRemoveCount = 3;

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Go forward in time by 2x the cache duration
  NSTimeInterval futureTimestamp = currentTimestamp + (2 * self.settings.cacheDurationSeconds);
  [self.settings reloadFromCacheWithGoogleAppID:TestGoogleAppID currentTimestamp:futureTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, YES);

  // Since the TTL just expired, do not clear settings
  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);

  // Pretend we fetched settings again, but they had different values
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  // Cache the settings
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // We should have the updated values that were fetched, and should not be expired
  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);
}

- (void)testCacheExpiredFromBuildInstanceID {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsActivated error:&error];
  XCTAssertNil(error, "%@", error);

  // 1 delete for clearing the cache key, plus 2 for the deletes from reloading and clearing the
  // cache and cache key
  self.fileManager.expectedRemoveCount = 3;

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Change the Build Instance ID
  self.appIDModel.buildInstanceID = FIRCLSDifferentMockBuildInstanceID;

  [self.settings reloadFromCacheWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, YES);

  // Since the TTL just expired, do not clear settings
  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);

  // Pretend we fetched settings again, but they had different values
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  // Cache the settings
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // We should have the updated values that were fetched, and should not be expired
  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);
}

- (void)testCacheExpiredFromAppVersion {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsActivated error:&error];
  XCTAssertNil(error, "%@", error);

  // 1 delete for clearing the cache key, plus 2 for the deletes from reloading and clearing the
  // cache and cache key
  self.fileManager.expectedRemoveCount = 3;

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Change the App Version
  self.appIDModel.displayVersion = FIRCLSDifferentMockAppDisplayVersion;
  self.appIDModel.buildVersion = FIRCLSDifferentMockAppBuildVersion;

  [self.settings reloadFromCacheWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, YES);

  // Since the TTL just expired, do not clear settings
  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);

  // Pretend we fetched settings again, but they had different values
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  // Cache the settings
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // We should have the updated values that were fetched, and should not be expired
  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);
}

- (void)testGoogleAppIDChanged {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Different Google App ID
  [self reloadFromCacheWithGoogleAppID:TestChangedGoogleAppID
                      currentTimestamp:currentTimestamp
                   expectedRemoveCount:2];

  XCTAssertEqual(self.settings.isCacheExpired, YES);

  // Clear the settings because they were for a different Google App ID

  // Pretend we fetched settings again, but they had different values
  [self writeSettings:FIRCLSTestSettingsActivated error:&error];
  XCTAssertNil(error, "%@", error);

  // Cache the settings with the new Google App ID
  [self.settings cacheSettingsWithGoogleAppID:TestChangedGoogleAppID
                             currentTimestamp:currentTimestamp];

  // Should have new values and not expired
  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);
}

// This is a weird case where we got settings, but never created a cache key for it. We are
// treating this as if the cache was invalid and re-fetching in this case.
- (void)testActivatedSettingsMissingCacheKey {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsActivated error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];

  // We only expect 1 removal because the cache key doesn't exist,
  // and deleteCachedSettings deletes the cache and the cache key
  [self reloadFromCacheWithGoogleAppID:TestGoogleAppID
                      currentTimestamp:currentTimestamp
                   expectedRemoveCount:1];

  XCTAssertEqual(self.settings.isCacheExpired, YES);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 3600);

  XCTAssertTrue(self.settings.collectReportsEnabled);
  XCTAssertTrue(self.settings.errorReportingEnabled);
  XCTAssertTrue(self.settings.customExceptionsEnabled);
  XCTAssertFalse(self.settings.metricKitCollectionEnabled);

  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.logBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.maxCustomExceptions, 8);
  XCTAssertEqual(self.settings.maxCustomKeys, 64);
  XCTAssertEqual(self.settings.onDemandUploadRate, 10);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 1.5);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 6);
}

// These tests are partially to make sure the SDK doesn't crash when it
// has corrupted settings.
- (void)testCorruptCache {
  // First write and load a good settings file
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Should have "Inverse" values
  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 12345);
  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);

  // Then write a corrupted one and cache + reload it
  [self writeSettings:FIRCLSTestSettingsCorrupted error:&error];
  XCTAssertNil(error, "%@", error);

  // Cache them, and reload. Since it's corrupted we should delete it all
  [self cacheSettingsWithGoogleAppID:TestGoogleAppID
                    currentTimestamp:currentTimestamp
                 expectedRemoveCount:2];

  // Should have default values because we deleted the cache and settingsDictionary
  XCTAssertEqual(self.settings.isCacheExpired, YES);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 3600);
  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);
}

- (void)testCorruptCacheKey {
  // First write and load a good settings file
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Should have "Inverse" values
  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 12345);
  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);
  XCTAssertEqual(self.settings.onDemandUploadRate, 15);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 3);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 9);

  // Then pretend we wrote a corrupted cache key and just reload it
  [self writeSettings:FIRCLSTestSettingsCorrupted error:&error isCacheKey:YES];
  XCTAssertNil(error, "%@", error);

  // Since settings themselves are corrupted, delete it all
  [self reloadFromCacheWithGoogleAppID:TestGoogleAppID
                      currentTimestamp:currentTimestamp
                   expectedRemoveCount:2];

  // Should have default values because we deleted the cache and settingsDictionary
  XCTAssertEqual(self.settings.isCacheExpired, YES);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 3600);
  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.onDemandUploadRate, 10);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 1.5);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 6);
}

#pragma mark - Malformed Settings

- (void)assertDefaultLimitsAndSwitches {
  XCTAssertTrue(self.settings.collectReportsEnabled);
  XCTAssertTrue(self.settings.errorReportingEnabled);
  XCTAssertTrue(self.settings.customExceptionsEnabled);
  XCTAssertFalse(self.settings.metricKitCollectionEnabled);
  XCTAssertTrue(self.settings.onDemandThreadSuspensionEnabled);

  XCTAssertEqual(self.settings.errorLogBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.logBufferSize, 64 * 1000);
  XCTAssertEqual(self.settings.maxCustomExceptions, 8);
  XCTAssertEqual(self.settings.maxCustomKeys, 64);
  XCTAssertEqual(self.settings.onDemandUploadRate, 10);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 1.5);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 6);
}

// A settings file that is valid JSON but not a JSON object should be discarded rather than crash
// every launch when the cached settings are read.
- (void)testSettingsNotADictionary {
  NSArray<NSString *> *malformedSettings = @[ @"[1,2,3]", @"[]", @"\"str\"", @"null", @"42", @"" ];

  for (NSString *settingsJSON in malformedSettings) {
    NSError *error = nil;
    [self writeSettings:settingsJSON error:&error];
    XCTAssertNil(error, "%@", error);

    NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
    // Invalid settings should be deleted along with the cache key.
    [self cacheSettingsWithGoogleAppID:TestGoogleAppID
                      currentTimestamp:currentTimestamp
                   expectedRemoveCount:2];

    XCTAssertNil(self.settings.settingsDictionary, @"%@", settingsJSON);
    XCTAssertEqual(self.settings.isCacheExpired, YES, @"%@", settingsJSON);
    XCTAssertEqual(self.settings.cacheDurationSeconds, 3600, @"%@", settingsJSON);
    [self assertDefaultLimitsAndSwitches];
  }
}

- (void)testSettingsGroupsWithWrongTypes {
  NSString *settingsJSON =
      @"{\"settings_version\":3,\"cache_duration\":60,\"features\":\"enabled\","
      @"\"session\":[1,2],\"app\":null,\"fabric\":7}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 60);
  [self assertDefaultLimitsAndSwitches];
}

- (void)testSettingsValuesWithWrongTypes {
  NSString *settingsJSON =
      @"{\"settings_version\":3,\"cache_duration\":null,"
      @"\"features\":{\"collect_logged_exceptions\":null,\"collect_reports\":[],"
      @"\"collect_metric_kit\":{}},"
      @"\"session\":{\"log_buffer_size\":\"big\",\"max_custom_exception_events\":null,"
      @"\"max_custom_key_value_pairs\":[1]},"
      @"\"on_demand_upload_rate_per_minute\":null,\"on_demand_backoff_base\":[],"
      @"\"on_demand_backoff_step_duration_seconds\":\"6\","
      @"\"on_demand_thread_recording_suspension_enabled\":{}}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 3600);
  [self assertDefaultLimitsAndSwitches];
}

- (void)testSettingsNegativeValues {
  NSString *settingsJSON =
      @"{\"settings_version\":3,\"cache_duration\":-1,"
      @"\"session\":{\"log_buffer_size\":-1,\"max_custom_exception_events\":-5,"
      @"\"max_custom_key_value_pairs\":-64},"
      @"\"on_demand_upload_rate_per_minute\":-10,\"on_demand_backoff_base\":-2,"
      @"\"on_demand_backoff_step_duration_seconds\":-6}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, 3600);
  [self assertDefaultLimitsAndSwitches];
}

- (void)testSettingsOutOfRangeValues {
  // -1e400 is parsed by NSJSONSerialization as -infinity.
  NSString *settingsJSON =
      @"{\"settings_version\":3,\"cache_duration\":1e20,"
      @"\"session\":{\"log_buffer_size\":4294967296,"
      @"\"max_custom_exception_events\":18446744073709551616,"
      @"\"max_custom_key_value_pairs\":1e300},"
      @"\"on_demand_upload_rate_per_minute\":-1e400,\"on_demand_backoff_base\":-1e400,"
      @"\"on_demand_backoff_step_duration_seconds\":4294967296}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Values too large for uint32_t are clamped rather than truncated.
  XCTAssertEqual(self.settings.isCacheExpired, NO);
  XCTAssertEqual(self.settings.cacheDurationSeconds, UINT32_MAX);
  XCTAssertEqual(self.settings.logBufferSize, UINT32_MAX);
  XCTAssertEqual(self.settings.maxCustomExceptions, UINT32_MAX);
  XCTAssertEqual(self.settings.maxCustomKeys, UINT32_MAX);
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, UINT32_MAX);

  // Non-finite values fall back to defaults.
  XCTAssertEqual(self.settings.onDemandUploadRate, 10);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 1.5);
}

- (void)testSettingsZeroAndFractionalValues {
  NSString *settingsJSON = @"{\"settings_version\":3,\"cache_duration\":0,"
                           @"\"session\":{\"log_buffer_size\":0,\"max_custom_exception_events\":0,"
                           @"\"max_custom_key_value_pairs\":0},"
                           @"\"on_demand_upload_rate_per_minute\":0,\"on_demand_backoff_base\":0,"
                           @"\"on_demand_backoff_step_duration_seconds\":0}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // Zero is a meaningful value for these settings and is respected.
  XCTAssertEqual(self.settings.cacheDurationSeconds, 0);
  XCTAssertEqual(self.settings.logBufferSize, 0);
  XCTAssertEqual(self.settings.maxCustomExceptions, 0);
  XCTAssertEqual(self.settings.maxCustomKeys, 0);
  XCTAssertEqual(self.settings.onDemandUploadRate, 0);
  XCTAssertEqual(self.settings.onDemandBackoffBase, 0);

  // The step duration is used as a divisor, so zero falls back to the default.
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 6);

  // A fractional step duration that truncates to zero also falls back to the default.
  [self writeSettings:@"{\"on_demand_backoff_step_duration_seconds\":0.5}" error:&error];
  XCTAssertNil(error, "%@", error);
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];
  XCTAssertEqual(self.settings.onDemandBackoffStepDuration, 6);
}

- (void)testCacheKeyNotADictionary {
  NSArray<NSString *> *malformedCacheKeys = @[ @"\"just a string\"", @"123", @"[1,2,3]", @"null" ];

  for (NSString *cacheKeyJSON in malformedCacheKeys) {
    NSError *error = nil;
    [self writeSettings:FIRCLSTestSettingsInverse error:&error];
    XCTAssertNil(error, "%@", error);

    NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
    [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];
    XCTAssertEqual(self.settings.errorLogBufferSize, 128000, @"%@", cacheKeyJSON);

    [self writeSettings:cacheKeyJSON error:&error isCacheKey:YES];
    XCTAssertNil(error, "%@", error);

    // An unreadable cache key invalidates the settings cache.
    [self reloadFromCacheWithGoogleAppID:TestGoogleAppID
                        currentTimestamp:currentTimestamp
                     expectedRemoveCount:2];

    XCTAssertEqual(self.settings.isCacheExpired, YES, @"%@", cacheKeyJSON);
    XCTAssertEqual(self.settings.cacheDurationSeconds, 3600, @"%@", cacheKeyJSON);
    [self assertDefaultLimitsAndSwitches];
  }
}

- (void)testCacheKeyGoogleAppIDWrongType {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  [self writeSettings:@"{\"google_app_id\":123}" error:&error isCacheKey:YES];
  XCTAssertNil(error, "%@", error);

  // A Google App ID that isn't a string is treated as a changed Google App ID.
  [self reloadFromCacheWithGoogleAppID:TestGoogleAppID
                      currentTimestamp:currentTimestamp
                   expectedRemoveCount:2];

  XCTAssertEqual(self.settings.isCacheExpired, YES);
  [self assertDefaultLimitsAndSwitches];
}

- (void)testCacheKeyValuesWithWrongTypes {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];
  XCTAssertEqual(self.settings.isCacheExpired, NO);

  NSString *cacheKeyJSON =
      [NSString stringWithFormat:@"{\"google_app_id\":\"%@\",\"created_at\":\"yesterday\","
                                 @"\"build_instance_id\":5,\"app_version\":null}",
                                 TestGoogleAppID];
  [self writeSettings:cacheKeyJSON error:&error isCacheKey:YES];
  XCTAssertNil(error, "%@", error);

  [self.settings reloadFromCacheWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  // The settings are kept, but are considered expired so they are fetched again.
  XCTAssertEqual(self.settings.isCacheExpired, YES);
  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);
}

- (void)testCacheKeyComparedWithNilBuildInstanceID {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];
  XCTAssertEqual(self.settings.isCacheExpired, NO);

  // A missing current Build Instance ID doesn't match the cached one.
  NSString *nilBuildInstanceID = nil;
  self.appIDModel.buildInstanceID = nilBuildInstanceID;

  [self.settings reloadFromCacheWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertEqual(self.settings.isCacheExpired, YES);
  XCTAssertEqual(self.settings.errorLogBufferSize, 128000);
}

- (void)testCacheKeyComparedWithNilGoogleAppID {
  NSError *error = nil;
  [self writeSettings:FIRCLSTestSettingsInverse error:&error];
  XCTAssertNil(error, "%@", error);

  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];
  XCTAssertEqual(self.settings.isCacheExpired, NO);

  // A missing current Google App ID is treated as a changed Google App ID.
  NSString *nilGoogleAppID = nil;
  [self reloadFromCacheWithGoogleAppID:nilGoogleAppID
                      currentTimestamp:currentTimestamp
                   expectedRemoveCount:2];

  XCTAssertEqual(self.settings.isCacheExpired, YES);
  [self assertDefaultLimitsAndSwitches];
}

- (void)testNewReportEndpointSettings {
  NSString *settingsJSON =
      @"{\"settings_version\":3,\"cache_duration\":60,\"app\":{\"report_upload_variant\":2}}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];
  XCTAssertNil(error, "%@", error);

  XCTAssertNotNil(self.settings.settingsDictionary);
  NSLog(@"[Debug Log] %@", self.settings.settingsDictionary);
}

- (void)testLegacyReportEndpointSettings {
  NSString *settingsJSON =
      @"{\"settings_version\":3,\"cache_duration\":60,\"app\":{\"report_upload_variant\":1}}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertNil(error, "%@", error);
}

- (void)testLegacyReportEndpointSettingsWithNonExistentKey {
  NSString *settingsJSON = @"{\"settings_version\":3,\"cache_duration\":60}";

  NSError *error = nil;
  [self writeSettings:settingsJSON error:&error];
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertNil(error, "%@", error);
}

- (void)testLegacyReportEndpointSettingsWithUnknownValue {
  NSString *newEndpointJSON =
      @"{\"settings_version\":3,\"cache_duration\":60,\"app\":{\"report_upload_variant\":xyz}}";

  NSError *error = nil;
  [self writeSettings:newEndpointJSON error:&error];
  NSTimeInterval currentTimestamp = [NSDate timeIntervalSinceReferenceDate];
  [self.settings cacheSettingsWithGoogleAppID:TestGoogleAppID currentTimestamp:currentTimestamp];

  XCTAssertNil(error, "%@", error);
}

- (void)testMachExceptionBehaviorFromAppInfo {
  // The key is defined in FIRCLSSettings.m, so we'll redefine it here for the test.
  NSString *const FirebaseCrashlyticsMachDefaultBehaviorKey =
      @"FirebaseCrashlyticsMachDefaultBehavior";

  NSDictionary *appInfoWithSetting = @{FirebaseCrashlyticsMachDefaultBehaviorKey : @YES};
  _settings = [[FIRCLSSettings alloc]
      initWithFileManager:_fileManager
               appIDModel:_appIDModel
                  appInfo:appInfoWithSetting
            deletionQueue:dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)];
  XCTAssertTrue(self.settings.machExceptionDefaultBehavior);

  NSDictionary *appInfoWithSettingString = @{FirebaseCrashlyticsMachDefaultBehaviorKey : @"true"};
  _settings = [[FIRCLSSettings alloc]
      initWithFileManager:_fileManager
               appIDModel:_appIDModel
                  appInfo:appInfoWithSettingString
            deletionQueue:dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)];
  XCTAssertTrue(self.settings.machExceptionDefaultBehavior);

  NSDictionary *appInfoWithSettingFalse = @{FirebaseCrashlyticsMachDefaultBehaviorKey : @NO};
  _settings = [[FIRCLSSettings alloc]
      initWithFileManager:_fileManager
               appIDModel:_appIDModel
                  appInfo:appInfoWithSettingFalse
            deletionQueue:dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)];
  XCTAssertFalse(self.settings.machExceptionDefaultBehavior);
}

@end
