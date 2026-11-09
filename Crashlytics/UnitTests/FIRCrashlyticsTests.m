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
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSContextInitGate.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRExceptionModel_Private.h"
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
@property(nonatomic, strong) dispatch_queue_t preInitAPIDispatchQueue;
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
- (void)resetContextInitPromiseForTesting:(nullable FBLPromise *)promise;

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

/// Spy subclass of FIRCLSMockOnDemandModel that records the calling thread and model snapshot.
@interface FIRCLSThreadTrackingOnDemandModel : FIRCLSMockOnDemandModel

@property(nonatomic, assign) BOOL lastCallWasOnMainThread;
@property(nonatomic, strong, nullable) NSThread *lastCallThread;
@property(nonatomic, strong, nullable) FIRExceptionModel *lastRecordedExceptionModel;
@property(nonatomic, assign) NSUInteger callCount;
@property(nonatomic, strong, nullable) NSException *exceptionToThrow;

@end

@implementation FIRCLSThreadTrackingOnDemandModel

- (BOOL)recordOnDemandExceptionIfQuota:(FIRExceptionModel *)exceptionModel
             withDataCollectionEnabled:(BOOL)dataCollectionEnabled
            usingExistingReportManager:(FIRCLSExistingReportManager *)existingReportManager {
  self.lastCallWasOnMainThread = [NSThread isMainThread];
  self.lastCallThread = [NSThread currentThread];
  self.lastRecordedExceptionModel = exceptionModel;
  self.callCount += 1;
  if (self.exceptionToThrow) {
    NSException *exception = self.exceptionToThrow;
    self.exceptionToThrow = nil;
    @throw exception;
  }
  return YES;
}

@end

/// Spy value object that returns a mutable string from `-description` and tracks evaluation thread
/// and invocation count.
@interface FIRCLSDescriptionTrackingObject : NSObject

@property(nonatomic, strong, nullable) NSMutableString *backingDescription;
@property(nonatomic, assign) NSUInteger descriptionCallCount;
@property(nonatomic, strong, nullable) NSThread *lastDescriptionThread;

- (instancetype)initWithInitialDescription:(nullable NSString *)initialDescription;

@end

@implementation FIRCLSDescriptionTrackingObject

- (instancetype)initWithInitialDescription:(nullable NSString *)initialDescription {
  self = [super init];
  if (self) {
    _backingDescription = [initialDescription mutableCopy];
  }
  return self;
}

- (NSString *)description {
  self.descriptionCallCount += 1;
  self.lastDescriptionThread = [NSThread currentThread];
  return self.backingDescription;
}

@end

@interface FIRCrashlyticsTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) FIRCLSThreadTrackingOnDemandModel *onDemandModel;
@property(nonatomic, strong) FIRCrashlytics *crashlytics;
@property(nonatomic, strong) NSMutableArray<NSData *> *allocatedPathBuffers;

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
  XCTAssertNotNil(self.crashlytics.preInitAPIDispatchQueue);
  XCTAssertEqualObjects(
      @(dispatch_queue_get_label(self.crashlytics.preInitAPIDispatchQueue)),
      [FIRCLSApplicationGetSDKBundleID() stringByAppendingString:@".pre-init-api"]);

  __block BOOL initSettled = NO;
  [self.crashlytics.contextInitPromise onQueue:self.crashlytics.preInitAPIDispatchQueue
                                          then:^id _Nullable(id _Nullable value) {
                                            initSettled = YES;
                                            return nil;
                                          }];
  NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:5.0];
  while (!initSettled && [deadline timeIntervalSinceNow] > 0) {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.005]];
  }
  XCTAssertTrue(initSettled);

  self.onDemandModel =
      [[FIRCLSThreadTrackingOnDemandModel alloc] initWithFIRCLSSettings:self.mockSettings
                                                            fileManager:self.fileManager
                                                             sleepBlock:^(int delay){
                                                             }];
  [self.crashlytics.managerData setValue:self.onDemandModel forKey:@"onDemandModel"];

  NSString *reportPath = [self.fileManager setupNewPathForExecutionIdentifier:@"test_report"];
  [self configureLoggingContextWithReportPath:reportPath];
}

- (void)tearDown {
  [self.crashlytics resetContextInitPromiseForTesting:nil];
  FIRCLSExecuteOnLoggingQueue(^{
  });
  if (FIRCLSGetBinaryImageQueue()) {
    dispatch_sync(FIRCLSGetBinaryImageQueue(), ^{
                  });
  }
  self.crashlytics = nil;
  [FIRCrashlytics resetInstanceForTesting];
  FIRCLSContextBaseDeinit();
  self.allocatedPathBuffers = nil;
  [[NSFileManager defaultManager] removeItemAtPath:self.fileManager.rootPath error:nil];

  [super tearDown];
}

#pragma mark - Helpers

- (const char *)allocatedContextPathInReport:(NSString *)reportPath fileName:(NSString *)fileName {
  const char *fsRep =
      [[reportPath stringByAppendingPathComponent:fileName] fileSystemRepresentation];
  NSData *buffer = [NSData dataWithBytes:fsRep length:strlen(fsRep) + 1];
  [self.allocatedPathBuffers addObject:buffer];
  return [buffer bytes];
}

/// Initializes `_firclsContext` for logging, custom keys, non-fatal errors, and custom exceptions
/// without installing Mach/signal/dyld handlers or write-protecting `_firclsContext.readonly`
/// (allowing `FIRCLSContextBaseDeinit()` in `-tearDown`).
- (void)configureLoggingContextWithReportPath:(NSString *)reportPath {
  self.allocatedPathBuffers = [NSMutableArray array];
  FIRCLSContextBaseInit();

  _firclsContext.readonly->logging.errorStorage.maxSize = 0;
  _firclsContext.readonly->logging.errorStorage.maxEntries = self.mockSettings.maxCustomExceptions;
  _firclsContext.readonly->logging.errorStorage.restrictBySize = false;
  _firclsContext.readonly->logging.errorStorage.entryCount =
      &_firclsContext.writable->logging.errorsCount;
  _firclsContext.readonly->logging.errorStorage.aPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportErrorAFile];
  _firclsContext.readonly->logging.errorStorage.bPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportErrorBFile];

  _firclsContext.readonly->logging.logStorage.maxSize = self.mockSettings.logBufferSize;
  _firclsContext.readonly->logging.logStorage.maxEntries = 0;
  _firclsContext.readonly->logging.logStorage.restrictBySize = true;
  _firclsContext.readonly->logging.logStorage.entryCount = NULL;
  _firclsContext.readonly->logging.logStorage.aPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportLogAFile];
  _firclsContext.readonly->logging.logStorage.bPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportLogBFile];

  _firclsContext.readonly->logging.customExceptionStorage.maxSize = 0;
  _firclsContext.readonly->logging.customExceptionStorage.maxEntries =
      self.mockSettings.maxCustomExceptions;
  _firclsContext.readonly->logging.customExceptionStorage.restrictBySize = false;
  _firclsContext.readonly->logging.customExceptionStorage.entryCount =
      &_firclsContext.writable->exception.customExceptionCount;
  _firclsContext.readonly->logging.customExceptionStorage.aPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportCustomExceptionAFile];
  _firclsContext.readonly->logging.customExceptionStorage.bPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportCustomExceptionBFile];

  _firclsContext.readonly->logging.userKVStorage.maxCount = self.mockSettings.maxCustomKeys;
  _firclsContext.readonly->logging.userKVStorage.incrementalPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportUserIncrementalKVFile];
  _firclsContext.readonly->logging.userKVStorage.compactedPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportUserCompactedKVFile];

  _firclsContext.readonly->logging.internalKVStorage.maxCount = 32;
  _firclsContext.readonly->logging.internalKVStorage.incrementalPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportInternalIncrementalKVFile];
  _firclsContext.readonly->logging.internalKVStorage.compactedPath =
      [self allocatedContextPathInReport:reportPath fileName:FIRCLSReportInternalCompactedKVFile];

  FIRCLSUserLoggingInit(&_firclsContext.readonly->logging, &_firclsContext.writable->logging);
  _firclsContext.readonly->initialized = true;
}

/// Waits for `crashlytics.preInitAPIDispatchQueue` and `_firclsLoggingQueue` to drain while keeping
/// the calling thread (including the main thread!) blocked on a semaphore. If any callback
/// attempted to dispatch onto `dispatch_get_main_queue()`, this helper would time out and fail.
- (void)drainQueuesBlockingCurrentThread {
  XCTAssertNotNil(self.crashlytics.contextInitPromise);
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  [self.crashlytics.contextInitPromise onQueue:self.crashlytics.preInitAPIDispatchQueue
                                        always:^{
                                          dispatch_semaphore_signal(sem);
                                        }];
  long waitResult =
      dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  XCTAssertEqual(waitResult, 0,
                 @"Timed out waiting on preInitAPIDispatchQueue without main runloop");

  // Drain any chained `onQueue:catch:` observer hop on `preInitAPIDispatchQueue`.
  dispatch_sync(self.crashlytics.preInitAPIDispatchQueue, ^{
                });

  // Also drain any trailing async compactions / A-B swaps on _firclsLoggingQueue.
  FIRCLSExecuteOnLoggingQueue(^{
  });
}

- (FBLPromise *)configurePendingInitPromise {
  FBLPromise *initPromise = [FBLPromise pendingPromise];
  [self.crashlytics resetContextInitPromiseForTesting:initPromise];
  return initPromise;
}

- (void)fulfillInitPromiseOffMain:(FBLPromise *)initPromise {
  [self fulfillInitPromiseOffMain:initPromise withValue:@YES];
}

- (void)fulfillInitPromiseOffMain:(FBLPromise *)initPromise withValue:(nullable id)value {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [initPromise fulfill:value];
  });
  [self drainQueuesBlockingCurrentThread];
}

- (void)rejectInitPromiseOffMain:(FBLPromise *)initPromise withError:(NSError *)error {
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_DEFAULT, 0), ^{
    [initPromise reject:error];
  });
  [self drainQueuesBlockingCurrentThread];
}

- (void)markContextReady {
  [self.crashlytics resetContextInitPromiseForTesting:[FBLPromise resolvedWith:@YES]];
  [self drainQueuesBlockingCurrentThread];
}

- (void)performOnBackgroundThread:(void (^)(NSThread *bgThread))block {
  dispatch_semaphore_t sem = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    NSThread *bgThread = [NSThread currentThread];
    XCTAssertFalse([NSThread isMainThread]);
    block(bgThread);
    dispatch_semaphore_signal(sem);
  });
  long waitResult =
      dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
  XCTAssertEqual(waitResult, 0, @"Timed out waiting on background caller while main was blocked");
}

- (NSArray<NSString *> *)decodedLogMessages {
  NSArray<NSDictionary *> *sections =
      FIRCLSFileReadSections(_firclsContext.readonly->logging.logStorage.aPath, true, nil);
  NSMutableArray<NSString *> *messages = [NSMutableArray arrayWithCapacity:sections.count];
  for (NSDictionary *section in sections) {
    [messages addObject:FIRCLSFileHexDecodeString([section[@"log"][@"msg"] UTF8String])];
  }
  return messages;
}

- (NSArray<NSDictionary *> *)errorAContents {
  return FIRCLSFileReadSections(_firclsContext.readonly->logging.errorStorage.aPath, true, nil);
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

#pragma mark - Pre-Init Buffering & Off-Main Drain

- (void)testPreInitLogsAndKeysFlushOffMainThread {
  XCTAssertTrue([NSThread isMainThread]);
  FBLPromise *initPromise = [self configurePendingInitPromise];

  [self.crashlytics log:@"pre-init log 1"];
  [self.crashlytics logWithFormat:@"pre-init formatted %d", 42];
  [self.crashlytics setUserID:@"user-123"];
  [self.crashlytics setCustomValue:@"val-1" forKey:@"key-1"];
  [self.crashlytics setCustomKeysAndValues:@{@"batch-k1" : @"batch-v1", @"batch-k2" : @99}];
  [self.crashlytics setDevelopmentPlatformName:@"Flutter"];
  [self.crashlytics setDevelopmentPlatformVersion:@"3.24.0"];

  XCTAssertEqual([self decodedLogMessages].count, 0);

  [self fulfillInitPromiseOffMain:initPromise];

  NSArray<NSString *> *expectedLogs = @[ @"pre-init log 1", @"pre-init formatted 42" ];
  XCTAssertEqualObjects([self decodedLogMessages], expectedLogs);

  NSDictionary<NSString *, NSString *> *userKVs = [self userKeyValues];
  XCTAssertEqualObjects(userKVs[@"key-1"], @"val-1");
  XCTAssertEqualObjects(userKVs[@"batch-k1"], @"batch-v1");
  XCTAssertEqualObjects(userKVs[@"batch-k2"], @"99");

  NSDictionary<NSString *, NSString *> *internalKVs = [self internalKeyValues];
  XCTAssertEqualObjects(internalKVs[FIRCLSUserIdentifierKey], @"user-123");
  XCTAssertEqualObjects(internalKVs[FIRCLSDevelopmentPlatformNameKey], @"Flutter");
  XCTAssertEqualObjects(internalKVs[FIRCLSDevelopmentPlatformVersionKey], @"3.24.0");
}

- (void)testPreInitErrorsAndExceptionsFlushOffMainThread {
  XCTAssertTrue([NSThread isMainThread]);
  FBLPromise *initPromise = [self configurePendingInitPromise];

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

  XCTAssertEqual([self errorAContents].count, 0);
  XCTAssertEqual([self customExceptionAContents].count, 0);
  XCTAssertEqual(self.onDemandModel.callCount, 0);

  [self fulfillInitPromiseOffMain:initPromise];

  NSArray<NSDictionary *> *errors = [self errorAContents];
  XCTAssertEqual(errors.count, 1);
  XCTAssertEqual([errors[0][@"error"][@"code"] integerValue], 101);
  XCTAssertGreaterThan([errors[0][@"error"][@"stacktrace"] count], 0);

  XCTAssertEqual([self customExceptionAContents].count, 1);
  XCTAssertEqual(self.onDemandModel.callCount, 1);
  XCTAssertFalse(self.onDemandModel.lastCallWasOnMainThread);
}

- (void)testRejectedInitPromiseDiscardsPreInitAndSubsequentCallsOffMainThread {
  XCTAssertTrue([NSThread isMainThread]);
  FBLPromise *initPromise = [self configurePendingInitPromise];

  [self.crashlytics log:@"discarded pre-init log"];
  [self.crashlytics setUserID:@"discarded-user"];
  [self.crashlytics setCustomValue:@"discarded-val" forKey:@"discarded-key"];
  [self.crashlytics recordError:[NSError errorWithDomain:@"com.test.reject" code:500 userInfo:nil]];
  FIRExceptionModel *ex = [FIRExceptionModel exceptionModelWithName:@"DiscardedEx"
                                                             reason:@"Discarded"];
  [self.crashlytics recordExceptionModel:ex];
  [self.crashlytics recordOnDemandExceptionModel:ex];

  NSError *initError = [NSError errorWithDomain:@"com.test.init" code:1 userInfo:nil];
  [self rejectInitPromiseOffMain:initPromise withError:initError];

  // Subsequent calls after failed initialization must also be ignored without buffering or running.
  [self.crashlytics log:@"post-rejection ignored log"];
  [self.crashlytics recordOnDemandExceptionModel:ex];

  XCTAssertEqual([self decodedLogMessages].count, 0);
  XCTAssertEqual([self errorAContents].count, 0);
  XCTAssertEqual([self customExceptionAContents].count, 0);
  XCTAssertEqual(self.onDemandModel.callCount, 0);
  XCTAssertNil([self userKeyValues][@"discarded-key"]);
  XCTAssertNil([self internalKeyValues][FIRCLSUserIdentifierKey]);
}

- (void)testFalseInitPromiseResultDiscardsPreInitAndSubsequentCallsOffMainThread {
  XCTAssertTrue([NSThread isMainThread]);
  FBLPromise *initPromise = [self configurePendingInitPromise];

  [self.crashlytics log:@"discarded on @NO"];
  [self.crashlytics setCustomValue:@"discarded-val" forKey:@"discarded-key"];
  FIRExceptionModel *ex = [FIRExceptionModel exceptionModelWithName:@"DiscardedEx"
                                                             reason:@"Discarded"];
  [self.crashlytics recordOnDemandExceptionModel:ex];

  [self fulfillInitPromiseOffMain:initPromise withValue:@NO];

  [self.crashlytics log:@"post-@NO ignored log"];
  [self.crashlytics recordOnDemandExceptionModel:ex];

  XCTAssertEqual([self decodedLogMessages].count, 0);
  XCTAssertEqual(self.onDemandModel.callCount, 0);
  XCTAssertNil([self userKeyValues][@"discarded-key"]);
}

- (void)testExceptionDuringPreInitFlushContinuesFlushingRemainingCallsAndMarksGateReady {
  XCTAssertTrue([NSThread isMainThread]);
  FBLPromise *initPromise = [self configurePendingInitPromise];
  self.onDemandModel.exceptionToThrow = [NSException exceptionWithName:@"SimulatedFlushException"
                                                                reason:@"Boom during flush"
                                                              userInfo:nil];

  [self.crashlytics log:@"log-before-exception"];
  FIRExceptionModel *ex = [FIRExceptionModel exceptionModelWithName:@"ThrowingEx"
                                                             reason:@"Triggers NSException"];
  [self.crashlytics recordOnDemandExceptionModel:ex];
  [self.crashlytics log:@"log-after-exception"];

  [self fulfillInitPromiseOffMain:initPromise];

  // Both surrounding pre-init logs still flush in FIFO order despite the throwing callback.
  NSArray<NSString *> *flushedExpected = @[ @"log-before-exception", @"log-after-exception" ];
  XCTAssertEqualObjects([self decodedLogMessages], flushedExpected);

  [self.crashlytics log:@"post-flush-inline-log"];
  NSArray<NSString *> *expected =
      @[ @"log-before-exception", @"log-after-exception", @"post-flush-inline-log" ];
  XCTAssertEqualObjects([self decodedLogMessages], expected);
}

- (void)testPreInitCallsExceedingMaxPendingBlocksDropsExcessAndAllowsPostInitCalls {
  XCTAssertTrue([NSThread isMainThread]);
  FBLPromise *initPromise = [self configurePendingInitPromise];

  for (NSUInteger i = 0; i < FIRCLSContextInitGateMaxPendingBlocks + 10; i++) {
    [self.crashlytics log:[NSString stringWithFormat:@"log-%lu", (unsigned long)i]];
  }

  [self fulfillInitPromiseOffMain:initPromise];

  NSArray<NSString *> *flushedLogs = [self decodedLogMessages];
  XCTAssertEqual(flushedLogs.count, FIRCLSContextInitGateMaxPendingBlocks);
  for (NSUInteger i = 0; i < FIRCLSContextInitGateMaxPendingBlocks; i++) {
    NSString *expectedLog = [NSString stringWithFormat:@"log-%lu", (unsigned long)i];
    XCTAssertEqualObjects(flushedLogs[i], expectedLog);
  }

  // Subsequent post-init calls run inline and are not dropped.
  [self.crashlytics log:@"post-init-log"];
  NSArray<NSString *> *allLogs = [self decodedLogMessages];
  XCTAssertEqual(allLogs.count, FIRCLSContextInitGateMaxPendingBlocks + 1);
  XCTAssertEqualObjects(allLogs.lastObject, @"post-init-log");
}

#pragma mark - Pre-Init Mutable Input Snapshotting

- (void)testPreInitSnapshotsMutableStringsForLogsUserIDAndPlatform {
  FBLPromise *initPromise = [self configurePendingInitPromise];

  NSMutableString *mutableLog = [@"initial-log" mutableCopy];
  NSMutableString *mutableUserID = [@"initial-user" mutableCopy];
  NSMutableString *mutablePlatform = [@"Unity" mutableCopy];
  NSMutableString *mutablePlatformVer = [@"2023.2" mutableCopy];

  [self.crashlytics log:mutableLog];
  [self.crashlytics setUserID:mutableUserID];
  [self.crashlytics setDevelopmentPlatformName:mutablePlatform];
  [self.crashlytics setDevelopmentPlatformVersion:mutablePlatformVer];

  [mutableLog setString:@"mutated-log"];
  [mutableUserID setString:@"mutated-user"];
  [mutablePlatform setString:@"MutatedPlatform"];
  [mutablePlatformVer setString:@"0.0"];

  [self fulfillInitPromiseOffMain:initPromise];

  XCTAssertEqualObjects([self decodedLogMessages], @[ @"initial-log" ]);
  NSDictionary<NSString *, NSString *> *internalKVs = [self internalKeyValues];
  XCTAssertEqualObjects(internalKVs[FIRCLSUserIdentifierKey], @"initial-user");
  XCTAssertEqualObjects(internalKVs[FIRCLSDevelopmentPlatformNameKey], @"Unity");
  XCTAssertEqualObjects(internalKVs[FIRCLSDevelopmentPlatformVersionKey], @"2023.2");
}

- (void)testPreInitSnapshotsCustomKeysAndEvaluatesDescriptionOnceOnCallerThread {
  FBLPromise *initPromise = [self configurePendingInitPromise];
  FIRCLSDescriptionTrackingObject *customValueObj =
      [[FIRCLSDescriptionTrackingObject alloc] initWithInitialDescription:@"custom-desc-initial"];

  [self performOnBackgroundThread:^(NSThread *bgThread) {
    NSMutableString *mutableKey = [@"custom-key" mutableCopy];
    [self.crashlytics setCustomValue:customValueObj forKey:mutableKey];
    XCTAssertEqual(customValueObj.descriptionCallCount, 1);
    XCTAssertEqual(customValueObj.lastDescriptionThread, bgThread);
    [mutableKey setString:@"mutated-key"];
    [customValueObj.backingDescription setString:@"custom-desc-mutated"];

    NSMutableString *dictKey = [@"dict-key" mutableCopy];
    NSMutableString *dictVal = [@"dict-val-initial" mutableCopy];
    NSMutableDictionary *mutableDict = [NSMutableDictionary dictionaryWithObject:dictVal
                                                                          forKey:dictKey];
    [self.crashlytics setCustomKeysAndValues:mutableDict];
    [dictKey setString:@"dict-key-mutated"];
    [dictVal setString:@"dict-val-mutated"];
    mutableDict[@"extra-after-call"] = @"should-not-appear";
  }];

  [self fulfillInitPromiseOffMain:initPromise];

  XCTAssertEqual(customValueObj.descriptionCallCount, 1);
  NSDictionary<NSString *, NSString *> *userKVs = [self userKeyValues];
  XCTAssertEqualObjects(userKVs[@"custom-key"], @"custom-desc-initial");
  XCTAssertNil(userKVs[@"mutated-key"]);
  XCTAssertEqualObjects(userKVs[@"dict-key"], @"dict-val-initial");
  XCTAssertNil(userKVs[@"extra-after-call"]);
}

- (void)testPreInitSnapshotsRecordErrorAndEvaluatesUserInfoOnceOnCallerThread {
  FBLPromise *initPromise = [self configurePendingInitPromise];
  FIRCLSDescriptionTrackingObject *errInfoObj =
      [[FIRCLSDescriptionTrackingObject alloc] initWithInitialDescription:@"err-info-initial"];
  FIRCLSDescriptionTrackingObject *extraInfoObj =
      [[FIRCLSDescriptionTrackingObject alloc] initWithInitialDescription:@"extra-info-initial"];

  [self performOnBackgroundThread:^(NSThread *bgThread) {
    NSMutableString *errDomain = [@"com.test.mutable" mutableCopy];
    NSError *error = [NSError errorWithDomain:errDomain
                                         code:77
                                     userInfo:@{@"infoKey" : errInfoObj}];
    NSMutableDictionary *extraUserInfo = [NSMutableDictionary dictionaryWithObject:extraInfoObj
                                                                            forKey:@"extraKey"];
    [self.crashlytics recordError:error userInfo:extraUserInfo];

    XCTAssertEqual(errInfoObj.descriptionCallCount, 1);
    XCTAssertEqual(errInfoObj.lastDescriptionThread, bgThread);
    XCTAssertEqual(extraInfoObj.descriptionCallCount, 1);
    XCTAssertEqual(extraInfoObj.lastDescriptionThread, bgThread);

    [errDomain setString:@"com.test.mutated"];
    [errInfoObj.backingDescription setString:@"err-info-mutated"];
    [extraInfoObj.backingDescription setString:@"extra-info-mutated"];
    extraUserInfo[@"addedLater"] = @"should-not-appear";
  }];

  [self fulfillInitPromiseOffMain:initPromise];

  XCTAssertEqual(errInfoObj.descriptionCallCount, 1);
  XCTAssertEqual(extraInfoObj.descriptionCallCount, 1);

  NSArray<NSDictionary *> *errors = [self errorAContents];
  XCTAssertEqual(errors.count, 1);
  NSDictionary *errorDict = errors[0][@"error"];
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([errorDict[@"domain"] UTF8String]),
                        @"com.test.mutable");
  NSArray *infoPairs = errorDict[@"info"];
  XCTAssertEqual(infoPairs.count, 1);
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([infoPairs[0][0] UTF8String]), @"infoKey");
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([infoPairs[0][1] UTF8String]),
                        @"err-info-initial");
  NSArray *extraInfoPairs = errorDict[@"extra_info"];
  XCTAssertEqual(extraInfoPairs.count, 1);
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([extraInfoPairs[0][0] UTF8String]), @"extraKey");
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([extraInfoPairs[0][1] UTF8String]),
                        @"extra-info-initial");
}

- (void)testPreInitSnapshotsMutableExceptionModels {
  FBLPromise *initPromise = [self configurePendingInitPromise];

  NSMutableString *customName = [@"OrigEx" mutableCopy];
  NSMutableString *customReason = [@"OrigReason" mutableCopy];
  NSMutableArray<FIRStackFrame *> *customFrames = [NSMutableArray
      arrayWithObject:[FIRStackFrame stackFrameWithSymbol:@"origSym" file:@"orig.m" line:11]];
  FIRExceptionModel *customEx = [FIRExceptionModel exceptionModelWithName:customName
                                                                   reason:customReason];
  customEx.stackTrace = customFrames;
  [self.crashlytics recordExceptionModel:customEx];

  [customName setString:@"MutatedEx"];
  [customReason setString:@"MutatedReason"];
  [customFrames removeAllObjects];
  customEx.name = @"ReassignedEx";
  customEx.reason = @"ReassignedReason";
  customEx.stackTrace = @[ [FIRStackFrame stackFrameWithSymbol:@"mutSym" file:@"mut.m" line:99] ];

  NSMutableString *onDemandName = [@"OrigOD" mutableCopy];
  NSMutableString *onDemandReason = [@"OrigODReason" mutableCopy];
  NSMutableArray<FIRStackFrame *> *onDemandFrames = [NSMutableArray
      arrayWithObject:[FIRStackFrame stackFrameWithSymbol:@"origODSym" file:@"od.m" line:22]];
  FIRExceptionModel *onDemandEx = [FIRExceptionModel exceptionModelWithName:onDemandName
                                                                     reason:onDemandReason];
  onDemandEx.stackTrace = onDemandFrames;
  onDemandEx.isFatal = YES;
  onDemandEx.onDemand = YES;
  [self.crashlytics recordOnDemandExceptionModel:onDemandEx];

  [onDemandName setString:@"MutatedOD"];
  [onDemandReason setString:@"MutatedODReason"];
  [onDemandFrames removeAllObjects];
  onDemandEx.name = @"ReassignedOD";
  onDemandEx.reason = @"ReassignedODReason";
  onDemandEx.stackTrace = @[];
  onDemandEx.isFatal = NO;
  onDemandEx.onDemand = NO;

  [self fulfillInitPromiseOffMain:initPromise];

  NSArray<NSDictionary *> *exceptions = [self customExceptionAContents];
  XCTAssertEqual(exceptions.count, 1);
  NSDictionary *exceptionDict = exceptions[0][@"exception"];
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([exceptionDict[@"name"] UTF8String]), @"OrigEx");
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([exceptionDict[@"reason"] UTF8String]),
                        @"OrigReason");
  NSArray *frames = exceptionDict[@"frames"];
  XCTAssertEqual(frames.count, 1);
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([frames[0][@"symbol"] UTF8String]), @"origSym");

  FIRExceptionModel *recordedOnDemand = self.onDemandModel.lastRecordedExceptionModel;
  XCTAssertEqualObjects(recordedOnDemand.name, @"OrigOD");
  XCTAssertEqualObjects(recordedOnDemand.reason, @"OrigODReason");
  XCTAssertEqual(recordedOnDemand.stackTrace.count, 1);
  XCTAssertTrue(recordedOnDemand.isFatal);
  XCTAssertTrue(recordedOnDemand.onDemand);
}

#pragma mark - Post-Init Synchronous Caller-Thread Execution

- (void)testPostInitBackgroundCallsPersistSynchronouslyOnCallerThreadWithoutMainHop {
  XCTAssertTrue([NSThread isMainThread]);
  [self markContextReady];

  [self performOnBackgroundThread:^(NSThread *bgThread) {
    [self.crashlytics log:@"post-init bg log"];
    XCTAssertEqualObjects([self decodedLogMessages], @[ @"post-init bg log" ]);

    [self.crashlytics setCustomValue:@"bg-val" forKey:@"bg-key"];
    XCTAssertEqualObjects([self userKeyValues][@"bg-key"], @"bg-val");

    [self.crashlytics recordError:[NSError errorWithDomain:@"com.test.bg" code:202 userInfo:nil]];
    XCTAssertEqual([self errorAContents].count, 1);

    FIRExceptionModel *customEx = [FIRExceptionModel exceptionModelWithName:@"BgEx" reason:@"bg"];
    [self.crashlytics recordExceptionModel:customEx];
    XCTAssertEqual([self customExceptionAContents].count, 1);

    FIRExceptionModel *onDemandEx = [FIRExceptionModel exceptionModelWithName:@"BgOnDemand"
                                                                       reason:@"From bg"];
    [self.crashlytics recordOnDemandExceptionModel:onDemandEx];
    XCTAssertEqual(self.onDemandModel.callCount, 1);
    XCTAssertFalse(self.onDemandModel.lastCallWasOnMainThread);
    XCTAssertEqual(self.onDemandModel.lastCallThread, bgThread);
  }];
}

- (void)testPostInitMainThreadCallsPersistSynchronouslyBeforeReturning {
  XCTAssertTrue([NSThread isMainThread]);
  [self markContextReady];

  [self.crashlytics log:@"post-init main log"];
  [self.crashlytics setCustomValue:@"main-val" forKey:@"main-key"];

  XCTAssertEqualObjects([self decodedLogMessages], @[ @"post-init main log" ]);
  XCTAssertEqualObjects([self userKeyValues][@"main-key"], @"main-val");
}

#pragma mark - Edge Cases & Guards

- (void)testLogIgnoresNilAndPreservesLiteralFormatSpecifiers {
  [self markContextReady];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertNoThrow([self.crashlytics log:nil]);
#pragma clang diagnostic pop
  XCTAssertEqual([self decodedLogMessages].count, 0);

  NSString *literalPercentMessage = @"100% complete %@ %s %d %n";
  [self.crashlytics log:literalPercentMessage];
  XCTAssertEqualObjects([self decodedLogMessages], @[ literalPercentMessage ]);
}

- (void)testNilErrorAndExceptionModelsAreIgnored {
  [self markContextReady];

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
  XCTAssertNoThrow([self.crashlytics recordError:nil]);
  XCTAssertNoThrow([self.crashlytics recordError:nil userInfo:@{@"k" : @"v"}]);
  XCTAssertNoThrow([self.crashlytics recordExceptionModel:nil]);
  XCTAssertNoThrow([self.crashlytics recordOnDemandExceptionModel:nil]);
#pragma clang diagnostic pop

  XCTAssertEqual([self errorAContents].count, 0);
  XCTAssertEqual([self customExceptionAContents].count, 0);
  XCTAssertEqual(self.onDemandModel.callCount, 0);
}

- (void)testClearingUserIDAndCustomKeysWithNilAndNSNull {
  [self markContextReady];

  FIRCLSDescriptionTrackingObject *nilDescObj =
      [[FIRCLSDescriptionTrackingObject alloc] initWithInitialDescription:nil];

  [self.crashlytics setUserID:@"temp-user"];
  [self.crashlytics setCustomValue:@"v1" forKey:@"clear-via-nil"];
  [self.crashlytics setCustomValue:@"v2" forKey:@"clear-via-nsnull"];
  [self.crashlytics setCustomValue:@"v3" forKey:@"keep-key"];
  [self.crashlytics setCustomValue:@"v4" forKey:@"clear-via-nil-desc-dict"];

  [self.crashlytics setUserID:nil];
  [self.crashlytics setCustomValue:nil forKey:@"clear-via-nil"];
  [self.crashlytics setCustomKeysAndValues:@{
    @"clear-via-nsnull" : [NSNull null],
    @"clear-via-nil-desc-dict" : nilDescObj,
  }];
  [self.crashlytics setCustomKeysAndValues:@{}];

  // Clearing keys with nil or NSNull triggers an async FIRCLSUserLoggingCompactKVEntries pass on
  // _firclsLoggingQueue that unlinks and rewrites compactedPath; drain it before reading KV files.
  FIRCLSExecuteOnLoggingQueue(^{
  });

  XCTAssertNil([self internalKeyValues][FIRCLSUserIdentifierKey]);
  NSDictionary<NSString *, NSString *> *userKVs = [self userKeyValues];
  XCTAssertNil(userKVs[@"clear-via-nil"]);
  XCTAssertNil(userKVs[@"clear-via-nsnull"]);
  XCTAssertNil(userKVs[@"clear-via-nil-desc-dict"]);
  XCTAssertEqualObjects(userKVs[@"keep-key"], @"v3");

  // Conversely, recordError:userInfo: skips nil-copied values rather than recording "<null>".
  NSError *error = [NSError errorWithDomain:@"com.test.nilinfo"
                                       code:1
                                   userInfo:@{@"kept" : @"ok", @"skipped" : nilDescObj}];
  [self.crashlytics recordError:error
                       userInfo:@{@"extraKept" : @"ok2", @"extraSkipped" : nilDescObj}];
  NSArray<NSDictionary *> *errors = [self errorAContents];
  XCTAssertEqual(errors.count, 1);
  NSArray *infoPairs = errors[0][@"error"][@"info"];
  XCTAssertEqual(infoPairs.count, 1);
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([infoPairs[0][0] UTF8String]), @"kept");
  NSArray *extraPairs = errors[0][@"error"][@"extra_info"];
  XCTAssertEqual(extraPairs.count, 1);
  XCTAssertEqualObjects(FIRCLSFileHexDecodeString([extraPairs[0][0] UTF8String]), @"extraKept");
}

- (void)testAPICallsBeforeSDKInitializationAreSafeNoOps {
  [self.crashlytics resetContextInitPromiseForTesting:nil];

  [self.crashlytics log:@"dropped-uninitialized"];
  [self.crashlytics setUserID:@"dropped-user"];
  [self.crashlytics setCustomValue:@"dropped-val" forKey:@"dropped-key"];
  [self.crashlytics recordError:[NSError errorWithDomain:@"com.test.drop" code:1 userInfo:nil]];
  FIRExceptionModel *droppedEx = [FIRExceptionModel exceptionModelWithName:@"Drop" reason:@"Drop"];
  [self.crashlytics recordExceptionModel:droppedEx];
  [self.crashlytics recordOnDemandExceptionModel:droppedEx];

  XCTAssertEqual([self decodedLogMessages].count, 0);
  XCTAssertEqual([self errorAContents].count, 0);
  XCTAssertEqual([self customExceptionAContents].count, 0);
  XCTAssertEqual(self.onDemandModel.callCount, 0);
  XCTAssertNil([self userKeyValues][@"dropped-key"]);
  XCTAssertNil([self internalKeyValues][FIRCLSUserIdentifierKey]);
}

@end
