// Copyright 2021 Google LLC
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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Controllers/FIRCLSMetricKitManager.h"
#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#if CLS_METRICKIT_SUPPORTED

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSExecutionIdentifierModel.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRAppFake.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockGDTCoreTransport.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockExistingReportManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCPUExceptionDiagnostic.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCallStackTree.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCrashDiagnostic.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXDiagnosticPayload.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXDiskWriteExceptionDiagnostic.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXHangDiagnostic.h"

#define TEST_GOOGLE_APP_ID (@"1:632950151350:ios:d5b0d08d4f00f4b1")

API_AVAILABLE(ios(14))
@interface FIRCLSMetricKitManagerTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockReportManager *reportManager;
@property(nonatomic, strong) FIRCLSMetricKitManager *metricKitManager;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) FIRCLSManagerData *managerData;
@property(nonatomic, strong) FIRCLSMockReportUploader *mockReportUploader;
@property(nonatomic, strong) FIRCLSTempMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSMockExistingReportManager *existingReportManager;

@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;
@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;
@property(nonatomic, strong) NSDate *beginTime;
@property(nonatomic, strong) NSDate *endTime;

@end

@implementation FIRCLSMetricKitManagerTests

- (void)setUp {
  [super setUp];

  FIRSetLoggerLevel(FIRLoggerLevelMax);

  FIRCLSContextBaseInit();

  id fakeApp = [[FIRAppFake alloc] init];
  self.dataArbiter = [[FIRCLSDataCollectionArbiter alloc] initWithApp:fakeApp withAppInfo:@{}];

  self.fileManager = [[FIRCLSTempMockFileManager alloc] init];

  // Delete cached settings
  [self.fileManager removeItemAtPath:_fileManager.settingsFilePath];

  FIRMockInstallations *iid = [[FIRMockInstallations alloc] initWithFID:@"test_token"];

  FIRMockGDTCORTransport *mockGoogleTransport =
      [[FIRMockGDTCORTransport alloc] initWithMappingID:@"id" transformers:nil target:0];
  FIRCLSApplicationIdentifierModel *appIDModel = [[FIRCLSApplicationIdentifierModel alloc] init];
  FIRCLSMockSettings *mockSettings =
      [[FIRCLSMockSettings alloc] initWithFileManager:self.fileManager appIDModel:appIDModel];

  _managerData = [[FIRCLSManagerData alloc] initWithGoogleAppID:TEST_GOOGLE_APP_ID
                                                googleTransport:mockGoogleTransport
                                                  installations:iid
                                                      analytics:nil
                                                    fileManager:self.fileManager
                                                    dataArbiter:self.dataArbiter
                                                       settings:mockSettings];

  self.mockReportUploader = [[FIRCLSMockReportUploader alloc] initWithManagerData:self.managerData];

  self.existingReportManager =
      [[FIRCLSMockExistingReportManager alloc] initWithManagerData:self.managerData
                                                    reportUploader:self.mockReportUploader];
  [self.fileManager createReportDirectories];
  [self.fileManager
      setupNewPathForExecutionIdentifier:self.managerData.executionIDModel.executionID];
  self.metricKitManager =
      [[FIRCLSMetricKitManager alloc] initWithManagerData:self.managerData
                                    existingReportManager:self.existingReportManager
                                              fileManager:self.fileManager];
  self.beginTime = [NSDate date];
  self.endTime = [NSDate dateWithTimeIntervalSinceNow:1];
}

- (void)tearDown {
  self.existingReportManager = nil;

  if ([[NSFileManager defaultManager] fileExistsAtPath:[self.fileManager rootPath]]) {
    assert([self.fileManager removeItemAtPath:[self.fileManager rootPath]]);
  }

  FIRCLSContextBaseDeinit();

  [super tearDown];
}

#pragma mark - Diagnostic Creation Helpers
- (FIRCLSMockMXCallStackTree *)createMockCallStackTree {
  NSString *callStackTreeString =
      @"{\n  \"callStacks\" : [\n    {\n      \"threadAttributed\" : true,\n      "
      @"\"callStackRootFrames\" : [\n        {\n          \"binaryUUID\" : "
      @"\"6387F46B-BE42-4575-8BFA-782CAAE676AA\",\n          \"offsetIntoBinaryTextSegment\" : "
      @"123,\n          \"sampleCount\" : 20,\n          \"binaryName\" : \"testBinaryName\",\n    "
      @"      \"address\" : 74565\n        }\n      ]\n    }\n  ],\n  \"callStackPerThread\" : "
      @"true\n}";
  return [[FIRCLSMockMXCallStackTree alloc] initWithStringData:callStackTreeString];
}

- (FIRCLSMockMXMetadata *)createMockMetadata {
  return [[FIRCLSMockMXMetadata alloc] initWithRegionFormat:@"US"
                                                  osVersion:@"iPhone OS 15.0 (19A5281j)"
                                                 deviceType:@"iPhone9,1"
                                    applicationBuildVersion:@"1"
                                       platformArchitecture:@"arm64"];
}

- (FIRCLSMockMXCrashDiagnostic *)createCrashDiagnostic {
  return [[FIRCLSMockMXCrashDiagnostic alloc]
        initWithCallStackTree:[self createMockCallStackTree]
            terminationReason:@"Namespace SIGNAL, Code 0xb"
      virtualMemoryRegionInfo:
          @"0 is not in any region.  Bytes before following region: 4000000000 REGION TYPE         "
          @"             START - END             [ VSIZE] PRT\\/MAX SHRMOD  REGION DETAIL UNUSED "
          @"SPACE AT START ---> __TEXT                 0000000000000000-0000000000000000 [   32K] "
          @"r-x\\/r-x SM=COW  ...pp\\/Test"
                exceptionType:@6
                exceptionCode:@0
                       signal:@11
                     metaData:[self createMockMetadata]
           applicationVersion:@"1"];
}

- (FIRCLSMockMXHangDiagnostic *)createHangDiagnostic {
  return [[FIRCLSMockMXHangDiagnostic alloc]
      initWithCallStackTree:[self createMockCallStackTree]
               hangDuration:[[NSMeasurement alloc] initWithDoubleValue:4.0
                                                                  unit:NSUnitDuration.seconds]
                   metaData:[self createMockMetadata]
         applicationVersion:@"1"];
}

- (FIRCLSMockMXCPUExceptionDiagnostic *)createCPUExceptionDiagnostic {
  return [[FIRCLSMockMXCPUExceptionDiagnostic alloc]
      initWithCallStackTree:[self createMockCallStackTree]
               totalCPUTime:[[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                  unit:NSUnitDuration.seconds]
           totalSampledTime:[[NSMeasurement alloc] initWithDoubleValue:2.0
                                                                  unit:NSUnitDuration.seconds]
                   metaData:[self createMockMetadata]
         applicationVersion:@"1"];
}

- (FIRCLSMockMXDiskWriteExceptionDiagnostic *)createDiskWriteExcptionDiagnostic {
  return [[FIRCLSMockMXDiskWriteExceptionDiagnostic alloc]
      initWithCallStackTree:[self createMockCallStackTree]
          totalWritesCaused:[[NSMeasurement alloc] initWithDoubleValue:24.0
                                                                  unit:NSUnitDuration.seconds]
                   metaData:[self createMockMetadata]
         applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createCrashDiagnosticPayload {
  NSDictionary *diagnostics = @{@"crashes" : @[ [self createCrashDiagnostic] ]};
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:self.beginTime
                                                       timeStampEnd:self.endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createHangDiagnosticPayload {
  NSDictionary *diagnostics = @{@"hangs" : @[ [self createHangDiagnostic] ]};
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:self.beginTime
                                                       timeStampEnd:self.endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createCPUExceptionDiagnosticPayload {
  NSDictionary *diagnostics =
      @{@"cpuExceptionDiagnostics" : @[ [self createCPUExceptionDiagnostic] ]};
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:self.beginTime
                                                       timeStampEnd:self.endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createDiskWriteExceptionDiagnosticPayload {
  NSDictionary *diagnostics =
      @{@"diskWriteExceptionDiagnostics" : @[ [self createDiskWriteExcptionDiagnostic] ]};
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:self.beginTime
                                                       timeStampEnd:self.endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createFullDiagnosticPayload {
  NSDictionary *diagnostics = @{
    @"crashes" : @[ [self createCrashDiagnostic] ],
    @"hangs" : @[ [self createHangDiagnostic] ],
    @"cpuExceptionDiagnostics" : @[ [self createCPUExceptionDiagnostic] ],
    @"diskWriteExceptionDiagnostics" : @[ [self createDiskWriteExcptionDiagnostic] ]
  };
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:self.beginTime
                                                       timeStampEnd:self.endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createEmptyDiagnosticPayload {
  NSDictionary *diagnostics = @{@"should" : @"be empty"};
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:self.beginTime
                                                       timeStampEnd:self.endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createDiagnosticPayloadWithMultipleCrashes {
  NSDictionary *diagnostics = @{
    @"crashes" : @[
      [self createCrashDiagnostic], [self createCrashDiagnostic], [self createCrashDiagnostic]
    ]
  };
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:self.beginTime
                                                       timeStampEnd:self.endTime
                                                 applicationVersion:@"1"];
}

- (void)checkMetadata:(NSDictionary *)metadata andThreads:(NSDictionary *)threads {
  XCTAssertNotNil(metadata, "MetricKit event should write metadata to file.");
  XCTAssertNotNil(threads, "MetricKit event should write threads to file.");

  XCTAssertTrue([[metadata objectForKey:@"appBuildVersion"] isEqualToString:@"1"]);
  XCTAssertTrue(
      [[metadata objectForKey:@"osVersion"] isEqualToString:@"iPhone OS 15.0 (19A5281j)"]);
  XCTAssertTrue([[metadata objectForKey:@"regionFormat"] isEqualToString:@"US"]);
  XCTAssertTrue([[metadata objectForKey:@"platformArchitecture"] isEqualToString:@"arm64"]);
  XCTAssertTrue([[metadata objectForKey:@"deviceType"] isEqualToString:@"iPhone9,1"]);

  XCTAssertTrue([threads objectForKey:@"crashed"]);                // YES
  XCTAssertEqual([[threads objectForKey:@"registers"] count], 0);  //{}
  XCTAssertEqual([[[threads objectForKey:@"stacktrace"] objectAtIndex:0] intValue], 74565);
}

#pragma mark - Path Helpers
- (NSArray *)contentsOfActivePath {
  return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.fileManager.activePath
                                                             error:nil];
}

- (BOOL)metricKitFileExistsInCurrentReport:(BOOL)currentReport fatalReport:(BOOL)fatalReport {
  NSString *newestUnsentReportID =
      [self.existingReportManager.newestUnsentReport.reportID stringByAppendingString:@"/"];
  NSString *currentReportID =
      [_managerData.executionIDModel.executionID stringByAppendingString:@"/"];
  NSString *reportID = (currentReport ? currentReportID : newestUnsentReportID);
  NSString *metricKitName =
      fatalReport ? @"metric_kit_fatal.clsrecord" : @"metric_kit_nonfatal.clsrecord";
  NSString *temp =
      [[self.fileManager.activePath stringByAppendingString:@"/"] stringByAppendingString:reportID];
  // Need to determine which report the file should be in
  return [[NSFileManager defaultManager]
      fileExistsAtPath:[temp stringByAppendingString:metricKitName]];
}

- (NSString *)contentsOfMetricKitFile:(BOOL)currentReport fatalReport:(BOOL)fatalReport {
  if (![self metricKitFileExistsInCurrentReport:currentReport fatalReport:fatalReport]) return nil;
  NSString *newestUnsentReportID =
      [self.existingReportManager.newestUnsentReport.reportID stringByAppendingString:@"/"];
  NSString *currentReportID =
      [_managerData.executionIDModel.executionID stringByAppendingString:@"/"];
  NSString *reportID = (currentReport ? currentReportID : newestUnsentReportID);
  NSString *metricKitName =
      fatalReport ? @"metric_kit_fatal.clsrecord" : @"metric_kit_nonfatal.clsrecord";
  NSString *filePath = [[[self.fileManager.activePath stringByAppendingString:@"/"]
      stringByAppendingString:reportID] stringByAppendingString:metricKitName];
  NSString *fileContents = [[NSString alloc] initWithContentsOfFile:filePath
                                                           encoding:NSUTF8StringEncoding
                                                              error:nil];
  return fileContents;
}

- (NSDictionary *)contentsOfMetricKitFileAsDictionary:(BOOL)currentReport
                                          fatalReport:(BOOL)fatalReport {
  NSString *metricKitFileContents = [self contentsOfMetricKitFile:currentReport
                                                      fatalReport:fatalReport];
  NSArray *metricKitFileArray = [metricKitFileContents componentsSeparatedByString:@"\n"];
  NSMutableDictionary *fileDictionary = [[NSMutableDictionary alloc] init];
  BOOL hasCrash = NO;
  for (NSString *json in metricKitFileArray) {
    NSString *itemKey = nil;
    if ([json containsString:@"metric_kit_fatal"])
      itemKey = @"crash_event";
    else if ([json containsString:@"exception"] && [json containsString:@"hang_event"])
      itemKey = @"hang_event";
    else if ([json containsString:@"exception"] && [json containsString:@"cpu_exception_event"])
      itemKey = @"cpu_exception_event";
    else if ([json containsString:@"exception"] &&
             [json containsString:@"disk_write_exception_event"])
      itemKey = @"disk_write_exception_event";
    else if ([json containsString:@"end_time"])
      itemKey = @"time";
    else if ([json containsString:@"threads"])
      itemKey = @"threads";
    NSData *itemData = [json dataUsingEncoding:NSUTF8StringEncoding];
    if (itemData == nil || itemKey == nil) continue;
    NSError *error = nil;
    NSDictionary *itemDictionary = [NSJSONSerialization JSONObjectWithData:itemData
                                                                   options:0
                                                                     error:&error];
    [fileDictionary setObject:itemDictionary forKey:itemKey];
    if ([itemKey isEqualToString:@"crash_event"]) {
      XCTAssertTrue(hasCrash == NO, "MetricKit reports should only have one crash event");
      hasCrash = YES;
    }
  }

  return fileDictionary;
}

- (void)createUnsentFatalReport {
  // create a report and put it in place
  NSString *reportPath =
      [self.fileManager.activePath stringByAppendingPathComponent:@"my_session_id"];
  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:reportPath
                                                        executionIdentifier:@"my_session_id"];

  [self.fileManager createDirectoryAtPath:report.path];
  [self.existingReportManager setShouldHaveExistingReport];
}

#pragma mark - Diagnostic Handling

- (void)testEmptyDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *emptyPayload = [self createEmptyDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ emptyPayload ]];
  XCTAssertFalse([self metricKitFileExistsInCurrentReport:YES fatalReport:NO],
                 "MetricKit report should not exist");
}

- (void)testCrashDiagnosticHandling {
  [self createUnsentFatalReport];
  FIRCLSMockMXDiagnosticPayload *crashPayload = [self createCrashDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ crashPayload ]];
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:NO fatalReport:YES],
                "MetricKit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary:NO fatalReport:YES];
  XCTAssertNotNil(fileDictionary, "MetricKit file should not be empty");

  NSDictionary *crashDictionary =
      [[fileDictionary objectForKey:@"crash_event"] objectForKey:@"metric_kit_fatal"];

  XCTAssertNotNil(crashDictionary, "MetricKit event should include a crash diagnostic");
  XCTAssertEqual([[crashDictionary objectForKey:@"time"] longValue],
                 [[NSNumber numberWithDouble:[self.beginTime timeIntervalSince1970]] longValue]);
  XCTAssertEqual([[crashDictionary objectForKey:@"end_time"] longValue],
                 [[NSNumber numberWithDouble:[self.endTime timeIntervalSince1970]] longValue]);

  XCTAssertEqual([[crashDictionary objectForKey:@"signal"] integerValue], 11);
  XCTAssertTrue([[crashDictionary objectForKey:@"app_version"] isEqualToString:@"1"]);
  XCTAssertTrue([[crashDictionary objectForKey:@"termination_reason"]
      isEqualToString:@"Namespace SIGNAL, Code 0xb"]);
  XCTAssertTrue([[crashDictionary objectForKey:@"virtual_memory_region_info"]
      isEqualToString:
          @"0 is not in any region.  Bytes before following region: 4000000000 REGION TYPE         "
          @"             START - END             [ VSIZE] PRT\\/MAX SHRMOD  REGION DETAIL UNUSED "
          @"SPACE AT START ---> __TEXT                 0000000000000000-0000000000000000 [   32K] "
          @"r-x\\/r-x SM=COW  ...pp\\/Test"]);
  XCTAssertEqual([[crashDictionary objectForKey:@"exception_code"] integerValue], 0);
  XCTAssertEqual([[crashDictionary objectForKey:@"exception_type"] integerValue], 6);
  XCTAssertTrue([[crashDictionary objectForKey:@"name"] isEqualToString:@"SIGABRT"]);
  XCTAssertTrue([[crashDictionary objectForKey:@"code_name"] isEqualToString:@"ABORT"]);

  NSDictionary *metadata = [crashDictionary objectForKey:@"metadata"];
  NSDictionary *threads =
      [[[fileDictionary objectForKey:@"threads"] objectForKey:@"threads"] objectAtIndex:0];

  [self checkMetadata:metadata andThreads:threads];
}

- (void)testHangDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *hangPayload = [self createHangDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ hangPayload ]];
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:YES fatalReport:NO],
                "MetricKit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary:YES fatalReport:NO];
  XCTAssertNotNil(fileDictionary, "MetricKit file should not be empty");

  NSDictionary *hangDictionary =
      [[fileDictionary objectForKey:@"hang_event"] objectForKey:@"exception"];

  XCTAssertNotNil(hangDictionary, "MetricKit event should include a hang diagnostic");
  XCTAssertEqual([[hangDictionary objectForKey:@"hang_duration"] integerValue], 4);
  XCTAssertEqual([[hangDictionary objectForKey:@"time"] longValue],
                 [[NSNumber numberWithDouble:[self.beginTime timeIntervalSince1970]] longValue]);
  XCTAssertEqual([[hangDictionary objectForKey:@"end_time"] longValue],
                 [[NSNumber numberWithDouble:[self.endTime timeIntervalSince1970]] longValue]);
  XCTAssertTrue([[hangDictionary objectForKey:@"app_version"] isEqualToString:@"1"]);

  NSDictionary *metadata = [hangDictionary objectForKey:@"metadata"];
  NSDictionary *threads = [[hangDictionary objectForKey:@"threads"] objectAtIndex:0];

  [self checkMetadata:metadata andThreads:threads];
}

- (void)testCPUExceptionDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *cpuPayload = [self createCPUExceptionDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ cpuPayload ]];
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:YES fatalReport:NO],
                "MetricKit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary:YES fatalReport:NO];
  XCTAssertNotNil(fileDictionary, "MetricKit file should not be empty");

  NSDictionary *cpuDictionary =
      [[fileDictionary objectForKey:@"cpu_exception_event"] objectForKey:@"exception"];

  XCTAssertNotNil(cpuDictionary, "MetricKit event should include a CPU exception diagnostic");
  XCTAssertEqual([[cpuDictionary objectForKey:@"total_cpu_time"] integerValue], 1);
  XCTAssertEqual([[cpuDictionary objectForKey:@"total_sampled_time"] integerValue], 2);
  XCTAssertTrue([[cpuDictionary objectForKey:@"app_version"] isEqualToString:@"1"]);
  XCTAssertEqual([[cpuDictionary objectForKey:@"time"] longValue],
                 [[NSNumber numberWithDouble:[self.beginTime timeIntervalSince1970]] longValue]);
  XCTAssertEqual([[cpuDictionary objectForKey:@"end_time"] longValue],
                 [[NSNumber numberWithDouble:[self.endTime timeIntervalSince1970]] longValue]);

  NSDictionary *metadata = [cpuDictionary objectForKey:@"metadata"];
  NSDictionary *threads = [[cpuDictionary objectForKey:@"threads"] objectAtIndex:0];

  [self checkMetadata:metadata andThreads:threads];
}

- (void)testDiskWriteExceptionDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *diskWritePayload =
      [self createDiskWriteExceptionDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ diskWritePayload ]];
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:YES fatalReport:NO],
                "MetricKit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary:YES fatalReport:NO];
  XCTAssertNotNil(fileDictionary, "MetricKit file should not be empty");

  NSDictionary *diskWriteDictionary =
      [[fileDictionary objectForKey:@"disk_write_exception_event"] objectForKey:@"exception"];

  XCTAssertNotNil(diskWriteDictionary,
                  "MetricKit event should include a disk write exception diagnostic");
  XCTAssertEqual([[diskWriteDictionary objectForKey:@"total_writes_caused"] longValue], 24);
  XCTAssertTrue([[diskWriteDictionary objectForKey:@"app_version"] isEqualToString:@"1"]);
  XCTAssertEqual([[diskWriteDictionary objectForKey:@"time"] longValue],
                 [[NSNumber numberWithDouble:[self.beginTime timeIntervalSince1970]] longValue]);
  XCTAssertEqual([[diskWriteDictionary objectForKey:@"end_time"] longValue],
                 [[NSNumber numberWithDouble:[self.endTime timeIntervalSince1970]] longValue]);

  NSDictionary *metadata = [diskWriteDictionary objectForKey:@"metadata"];
  NSDictionary *threads = [[diskWriteDictionary objectForKey:@"threads"] objectAtIndex:0];

  [self checkMetadata:metadata andThreads:threads];
}

- (void)testFullDiagnosticHandling {
  [self createUnsentFatalReport];
  FIRCLSMockMXDiagnosticPayload *fullPayload = [self createFullDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ fullPayload ]];
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:NO fatalReport:YES],
                "MetricKit fatal report should exist");
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:YES fatalReport:NO],
                "MetricKit nonfatal report should exist");

  NSDictionary *fatalFileDictionary = [self contentsOfMetricKitFileAsDictionary:NO fatalReport:YES];
  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary:YES fatalReport:NO];

  XCTAssertNotNil(fileDictionary, "MetricKit nonfatal file should not be empty");
  XCTAssertNotNil(fatalFileDictionary, "MetricKit fatal file should not be empty");

  XCTAssertNil([fatalFileDictionary objectForKey:@"hang_event"]);
  XCTAssertNil([fatalFileDictionary objectForKey:@"cpu_exception_event"]);
  XCTAssertNil([fatalFileDictionary objectForKey:@"disk_write_exception_event"]);
  XCTAssertNil([fileDictionary objectForKey:@"crash_event"]);
  XCTAssertNil([fileDictionary objectForKey:@"time"]);

  NSDictionary *hangDictionary =
      [[fileDictionary objectForKey:@"hang_event"] objectForKey:@"exception"];
  NSDictionary *cpuDictionary =
      [[fileDictionary objectForKey:@"cpu_exception_event"] objectForKey:@"exception"];
  NSDictionary *diskDictionary =
      [[fileDictionary objectForKey:@"disk_write_exception_event"] objectForKey:@"exception"];
  NSDictionary *crashDictionary =
      [[fatalFileDictionary objectForKey:@"crash_event"] objectForKey:@"metric_kit_fatal"];

  XCTAssertNotNil(hangDictionary, "MetricKit event should include a hang diagnostic");
  XCTAssertNotNil(cpuDictionary, "MetricKit event should include a CPU exception diagnostic");
  XCTAssertNotNil(diskDictionary,
                  "MetricKit event should include a disk write exception diagnostic");
  XCTAssertNotNil(crashDictionary, "MetricKit event should include a crash diagnostic");
}

- (void)testPayloadWithMultipleCrashesHandling {
  [self createUnsentFatalReport];
  FIRCLSMockMXDiagnosticPayload *payloadWithMultipleCrashes =
      [self createDiagnosticPayloadWithMultipleCrashes];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ payloadWithMultipleCrashes ]];
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:NO fatalReport:YES],
                "MetricKit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary:NO fatalReport:YES];
  XCTAssertNotNil(fileDictionary, "MetricKit file should not be empty");

  NSDictionary *crashDictionary =
      [[fileDictionary objectForKey:@"crash_event"] objectForKey:@"metric_kit_fatal"];
  XCTAssertNotNil(crashDictionary, "MetricKit event should include a crash diagnostic");
}

- (void)testMultiplePayloadsWithCrashesHandling {
  [self createUnsentFatalReport];
  FIRCLSMockMXDiagnosticPayload *crashPayload = [self createCrashDiagnosticPayload];
  FIRCLSMockMXDiagnosticPayload *hangPayload = [self createHangDiagnosticPayload];
  FIRCLSMockMXDiagnosticPayload *cpuPayload = [self createCPUExceptionDiagnosticPayload];
  [self.metricKitManager
      didReceiveDiagnosticPayloads:@[ crashPayload, hangPayload, crashPayload, cpuPayload ]];
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:NO fatalReport:YES],
                "MetricKit fatal report should exist");
  XCTAssertTrue([self metricKitFileExistsInCurrentReport:YES fatalReport:NO],
                "MetricKit nonfatal report should exist");

  NSDictionary *fatalFileDictionary = [self contentsOfMetricKitFileAsDictionary:NO fatalReport:YES];
  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary:YES fatalReport:NO];

  XCTAssertNotNil(fileDictionary, "MetricKit nonfatal file should not be empty");
  XCTAssertNotNil(fatalFileDictionary, "MetricKit fatal file should not be empty");

  XCTAssertNil([fatalFileDictionary objectForKey:@"hang_event"]);
  XCTAssertNil([fatalFileDictionary objectForKey:@"cpu_exception_event"]);
  XCTAssertNil([fatalFileDictionary objectForKey:@"disk_write_exception_event"]);
  XCTAssertNil([fileDictionary objectForKey:@"crash_event"]);
  XCTAssertNil([fileDictionary objectForKey:@"time"]);

  NSDictionary *hangDictionary =
      [[fileDictionary objectForKey:@"hang_event"] objectForKey:@"exception"];
  NSDictionary *cpuDictionary =
      [[fileDictionary objectForKey:@"cpu_exception_event"] objectForKey:@"exception"];
  NSDictionary *crashDictionary =
      [[fatalFileDictionary objectForKey:@"crash_event"] objectForKey:@"metric_kit_fatal"];

  XCTAssertNotNil(hangDictionary, "MetricKit event should include a hang diagnostic");
  XCTAssertNotNil(cpuDictionary, "MetricKit event should include a CPU exception diagnostic");
  XCTAssertNotNil(crashDictionary, "MetricKit event should include a crash diagnostic");
}

@end
#endif
