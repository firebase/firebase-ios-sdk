// Copyright 2026 Google LLC
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

#import <XCTest/XCTest.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FBLPromise+Testing.h"

#import "Crashlytics/Crashlytics/Components/FIRCLSApplication.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSUserLogging.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSContextManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlytics.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRExceptionModel.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRStackFrame.h"

#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRAppFake.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockOnDemandModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"

#define TEST_GOOGLE_APP_ID (@"1:632950151350:ios:d5b0d08d4f00f4b1")

@protocol FIRAnalyticsInterop;
@protocol FIRRemoteConfigInterop;
@protocol FIRSessionsProvider;

@interface FIRCrashlytics (Testing)

@property(nonatomic, strong) FIRCLSManagerData *managerData;
@property(nonatomic, strong) dispatch_queue_t apiDispatchQueue;
@property(nonatomic, nullable) FBLPromise *contextInitPromise;

- (nullable instancetype)initWithApp:(FIRApp *)app
                             appInfo:(NSDictionary *)appInfo
                       installations:(FIRInstallations *)installations
                           analytics:(nullable id<FIRAnalyticsInterop>)analytics
                            sessions:(nullable id<FIRSessionsProvider>)sessions
                        remoteConfig:(nullable id<FIRRemoteConfigInterop>)remoteConfig;

- (void)setDevelopmentPlatformName:(NSString *)developmentPlatformName;
- (void)setDevelopmentPlatformVersion:(NSString *)developmentPlatformVersion;
- (void)recordOnDemandExceptionModel:(FIRExceptionModel *)exceptionModel;
+ (void)resetInstanceForTesting;

@end

/// Fake FIRApp that also provides `options` for `-[FIRCrashlytics initWithApp:...]`.
@interface FIRCLSAppWithOptionsFake : FIRAppFake

@property(nonatomic, strong) FIROptions *options;

@end

@implementation FIRCLSAppWithOptionsFake

- (instancetype)init {
  self = [super init];
  if (self) {
    _options = [[FIROptions alloc] initWithGoogleAppID:TEST_GOOGLE_APP_ID GCMSenderID:@"123456789"];
  }
  return self;
}

@end

/// Spy subclass of FIRCLSMockOnDemandModel that records whether on-demand recording ran on main.
@interface FIRCLSThreadTrackingOnDemandModel : FIRCLSMockOnDemandModel

@property(nonatomic, assign) BOOL lastCallWasOnMainThread;
@property(nonatomic, assign) NSUInteger callCount;

@end

@implementation FIRCLSThreadTrackingOnDemandModel

- (BOOL)recordOnDemandExceptionIfQuota:(FIRExceptionModel *)exceptionModel
             withDataCollectionEnabled:(BOOL)dataCollectionEnabled
            usingExistingReportManager:(FIRCLSExistingReportManager *)existingReportManager {
  self.lastCallWasOnMainThread = [NSThread isMainThread];
  self.callCount += 1;
  return YES;
}

@end

@interface FIRCrashlyticsTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) FIRCLSThreadTrackingOnDemandModel *onDemandModel;
@property(nonatomic, strong) FIRCrashlytics *crashlytics;

@end

@implementation FIRCrashlyticsTests

- (void)setUp {
  [super setUp];

  self.fileManager = [[FIRCLSMockFileManager alloc] init];
  [[NSFileManager defaultManager] removeItemAtPath:self.fileManager.rootPath error:nil];
  [self.fileManager createReportDirectories];

  FABMockApplicationIdentifierModel *appIDModel = [[FABMockApplicationIdentifierModel alloc] init];
  self.mockSettings = [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager
                                                           appIDModel:appIDModel
                                                              appInfo:@{}];

  [FIRCrashlytics resetInstanceForTesting];
  // Passing the legacy plist key makes validateAppIdentifiers return NO immediately so
  // startWithProfiling resolves without starting network requests or background report uploads.
  self.crashlytics =
      [[FIRCrashlytics alloc] initWithApp:(id)[[FIRCLSAppWithOptionsFake alloc] init]
                                  appInfo:@{@"firebase_crashlytics_collection_enabled" : @NO}
                            installations:(id)[[FIRMockInstallations alloc] initWithFID:@"test_fid"]
                                analytics:nil
                                 sessions:nil
                             remoteConfig:nil];
  XCTAssertNotNil(self.crashlytics);
  XCTAssertNotNil(self.crashlytics.apiDispatchQueue);
  XCTAssertEqualObjects(@(dispatch_queue_get_label(self.crashlytics.apiDispatchQueue)),
                        [FIRCLSApplicationGetSDKBundleID() stringByAppendingString:@".api"]);

  self.onDemandModel =
      [[FIRCLSThreadTrackingOnDemandModel alloc] initWithFIRCLSSettings:self.mockSettings
                                                            fileManager:self.fileManager
                                                             sleepBlock:^(int delay){
                                                             }];
  [self.crashlytics.managerData setValue:self.onDemandModel forKey:@"onDemandModel"];

  NSString *reportPath = [self.fileManager setupNewPathForExecutionIdentifier:@"test_report"];
  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                                        executionIdentifier:@"test_report"];
  FBLPromiseAwait([[[FIRCLSContextManager alloc] init] setupContextWithReport:report
                                                                     settings:self.mockSettings
                                                                  fileManager:self.fileManager],
                  nil);
}

- (void)tearDown {
  if (self.crashlytics.apiDispatchQueue) {
    dispatch_sync(self.crashlytics.apiDispatchQueue, ^{
                  });
  }
  FIRCLSExecuteOnLoggingQueue(^{
  });
  if (FIRCLSGetBinaryImageQueue()) {
    dispatch_sync(FIRCLSGetBinaryImageQueue(), ^{
                  });
  }
  self.crashlytics.contextInitPromise = nil;
  self.crashlytics = nil;
  [[NSFileManager defaultManager] removeItemAtPath:self.fileManager.rootPath error:nil];

  [super tearDown];
}

#pragma mark - Helpers

/// Waits for `crashlytics.apiDispatchQueue` and `_firclsLoggingQueue` to drain while keeping the
/// calling thread (including the main thread!) blocked on a semaphore. If any callback attempted
/// to dispatch onto `dispatch_get_main_queue()`, this helper would time out and fail the test.
- (void)drainQueuesBlockingCurrentThread {
  XCTAssertNotNil(self.crashlytics.contextInitPromise);
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [self.crashlytics.contextInitPromise onQueue:self.crashlytics.apiDispatchQueue
                                          then:^id _Nullable(id _Nullable value) {
                                            dispatch_semaphore_signal(sem);
                                            return nil;
                                          }];
  long waitResult =
      dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  XCTAssertEqual(waitResult, 0, @"Timed out waiting on apiDispatchQueue without main runloop");

  // Also drain any trailing async compactions / A-B swaps on _firclsLoggingQueue.
  FIRCLSExecuteOnLoggingQueue(^{
  });
}

- (NSArray<NSDictionary *> *)logAContents {
  return FIRCLSFileReadSections(_firclsContext.readonly->logging.logStorage.aPath, true, nil);
}

- (NSArray<NSDictionary *> *)errorAContents {
  return FIRCLSFileReadSections(_firclsContext.readonly->logging.errorStorage.aPath, true, nil);
}

- (NSArray<NSDictionary *> *)errorBContents {
  return FIRCLSFileReadSections(_firclsContext.readonly->logging.errorStorage.bPath, true, nil);
}

- (NSArray<NSDictionary *> *)customExceptionAContents {
  return FIRCLSFileReadSections(_firclsContext.readonly->logging.customExceptionStorage.aPath, true,
                                nil);
}

- (NSDictionary<NSString *, NSString *> *)userKeyValues {
  return FIRCLSUserLoggingGetCompactedKVEntries(&_firclsContext.readonly->logging.userKVStorage,
                                                true);
}

- (NSDictionary<NSString *, NSString *> *)internalKeyValues {
  return FIRCLSUserLoggingGetCompactedKVEntries(&_firclsContext.readonly->logging.internalKVStorage,
                                                true);
}

#pragma mark - Tests

- (void)testPreInitAPICallsExecuteOffMainThreadAndPersistAllRecords {
  XCTAssertTrue([NSThread isMainThread]);
  FBLPromise *initPromise = [FBLPromise pendingPromise];
  self.crashlytics.contextInitPromise = initPromise;

  [self.crashlytics log:@"pre-init log 1"];
  [self.crashlytics logWithFormat:@"pre-init formatted %d", 42];
  [self.crashlytics setUserID:@"user-123"];
  [self.crashlytics setCustomValue:@"val-1" forKey:@"key-1"];
  [self.crashlytics setCustomKeysAndValues:@{@"batch-k1" : @"batch-v1", @"batch-k2" : @99}];
  [self.crashlytics setDevelopmentPlatformName:@"Flutter"];
  [self.crashlytics setDevelopmentPlatformVersion:@"3.24.0"];
  [self.crashlytics recordError:[NSError errorWithDomain:@"com.test.preinit"
                                                    code:101
                                                userInfo:@{@"errKey" : @"errVal"}]];

  FIRExceptionModel *customEx = [FIRExceptionModel exceptionModelWithName:@"CustomEx"
                                                                   reason:@"Pre-init reason"];
  customEx.stackTrace = @[ [FIRStackFrame stackFrameWithSymbol:@"fn" file:@"f.dart" line:10] ];
  [self.crashlytics recordExceptionModel:customEx];

  FIRExceptionModel *onDemandEx = [FIRExceptionModel exceptionModelWithName:@"OnDemandEx"
                                                                     reason:@"On-demand reason"];
  onDemandEx.stackTrace = @[ [FIRStackFrame stackFrameWithSymbol:@"odFn" file:@"od.dart" line:20] ];
  [self.crashlytics recordOnDemandExceptionModel:onDemandEx];

  // Nothing should have executed before initPromise resolves.
  XCTAssertEqual([self logAContents].count, 0);
  XCTAssertEqual(self.onDemandModel.callCount, 0);

  // Fulfill initPromise from a background queue while blocking the main thread on a semaphore
  // (never spinning NSRunLoop.mainRunLoop). Every queued API call must flush off-main.
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [initPromise fulfill:@YES];
  });
  [self drainQueuesBlockingCurrentThread];

  XCTAssertEqual(self.onDemandModel.callCount, 1);
  XCTAssertFalse(self.onDemandModel.lastCallWasOnMainThread);

  NSArray<NSDictionary *> *logs = [self logAContents];
  XCTAssertEqual(logs.count, 2);
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([logs[0][@"log"][@"msg"] UTF8String]),
                        @"pre-init log 1");
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([logs[1][@"log"][@"msg"] UTF8String]),
                        @"pre-init formatted 42");

  NSDictionary<NSString *, NSString *> *userKVs = [self userKeyValues];
  XCTAssertEqualObjects(userKVs[@"key-1"], @"val-1");
  XCTAssertEqualObjects(userKVs[@"batch-k1"], @"batch-v1");
  XCTAssertEqualObjects(userKVs[@"batch-k2"], @"99");

  NSDictionary<NSString *, NSString *> *internalKVs = [self internalKeyValues];
  XCTAssertEqualObjects(internalKVs[FIRCLSUserIdentifierKey], @"user-123");
  XCTAssertEqualObjects(internalKVs[FIRCLSDevelopmentPlatformNameKey], @"Flutter");
  XCTAssertEqualObjects(internalKVs[FIRCLSDevelopmentPlatformVersionKey], @"3.24.0");

  NSArray<NSDictionary *> *errors = [self errorAContents];
  XCTAssertEqual(errors.count, 1);
  XCTAssertEqual([errors[0][@"error"][@"code"] integerValue], 101);

  NSArray<NSDictionary *> *exceptions = [self customExceptionAContents];
  XCTAssertEqual(exceptions.count, 1);
}

- (void)testPostInitAPICallsFromMainAndBackgroundThreadsExecuteOffMainThread {
  XCTAssertTrue([NSThread isMainThread]);
  self.crashlytics.contextInitPromise = [FBLPromise resolvedWith:@YES];

  // Invoke from main thread while blocking main runloop afterwards.
  [self.crashlytics log:@"post-init main log"];
  [self.crashlytics setCustomValue:@"main-val" forKey:@"main-key"];

  // Also invoke from a background queue.
  dispatch_sync(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    [self.crashlytics log:@"post-init bg log"];
    [self.crashlytics setCustomValue:@"bg-val" forKey:@"bg-key"];
    FIRExceptionModel *onDemandEx = [FIRExceptionModel exceptionModelWithName:@"BgOnDemand"
                                                                       reason:@"From bg"];
    [self.crashlytics recordOnDemandExceptionModel:onDemandEx];
  });

  [self drainQueuesBlockingCurrentThread];

  XCTAssertEqual(self.onDemandModel.callCount, 1);
  XCTAssertFalse(self.onDemandModel.lastCallWasOnMainThread);

  NSArray<NSDictionary *> *logs = [self logAContents];
  XCTAssertEqual(logs.count, 2);
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([logs[0][@"log"][@"msg"] UTF8String]),
                        @"post-init main log");
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([logs[1][@"log"][@"msg"] UTF8String]),
                        @"post-init bg log");

  NSDictionary<NSString *, NSString *> *userKVs = [self userKeyValues];
  XCTAssertEqualObjects(userKVs[@"main-key"], @"main-val");
  XCTAssertEqualObjects(userKVs[@"bg-key"], @"bg-val");
}

- (void)testFIFOOrderingKVCompactionAndABFileRotationAcrossInitTransition {
  FBLPromise *initPromise = [FBLPromise pendingPromise];
  self.crashlytics.contextInitPromise = initPromise;

  // Queue 50 updates pre-init, writing both distinct keys (to exceed maxIncrementalCount = 64)
  // and sequential overwrites of "order-key".
  for (int i = 0; i < 50; i++) {
    NSString *distinctKey = [NSString stringWithFormat:@"distinct-%d", i % 60];
    [self.crashlytics setCustomValue:[NSString stringWithFormat:@"v-%d", i] forKey:distinctKey];
    [self.crashlytics setCustomValue:[NSString stringWithFormat:@"seq-%d", i] forKey:@"order-key"];
  }

  // Record 10 non-fatal errors (maxEntries is 8 by default, so 8 should land in A and 2 in B).
  for (int i = 0; i < 10; i++) {
    [self.crashlytics recordError:[NSError errorWithDomain:@"com.test.rotate" code:i userInfo:nil]];
  }

  // Resolve initPromise on a background thread and immediately enqueue 50 more sequential updates.
  dispatch_group_t bgGroup = dispatch_group_create();
  dispatch_group_async(bgGroup, dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [initPromise fulfill:@YES];
  });
  for (int i = 50; i < 100; i++) {
    [self.crashlytics setCustomValue:[NSString stringWithFormat:@"seq-%d", i] forKey:@"order-key"];
  }
  dispatch_group_wait(bgGroup, DISPATCH_TIME_FOREVER);

  [self drainQueuesBlockingCurrentThread];

  NSDictionary<NSString *, NSString *> *userKVs = [self userKeyValues];
  XCTAssertEqualObjects(userKVs[@"order-key"], @"seq-99");
  XCTAssertLessThanOrEqual(userKVs.count, _firclsContext.readonly->logging.userKVStorage.maxCount);

  XCTAssertEqual([self errorAContents].count, 8);
  XCTAssertEqual([self errorBContents].count, 2);
}

@end
