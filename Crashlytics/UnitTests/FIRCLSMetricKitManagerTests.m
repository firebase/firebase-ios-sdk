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

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "FirebaseCore/Sources/Private/FirebaseCoreInternal.h"

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSAnalyticsManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSExistingReportManager.h"
#import "Crashlytics/Crashlytics/Controllers/FIRCLSManagerData.h"
#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSSettings.h"

#import "Crashlytics/Crashlytics/Settings/Models/FIRCLSApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FABMockApplicationIdentifierModel.h"
#import "Crashlytics/UnitTests/Mocks/FIRAppFake.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockReportUploader.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSettings.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSTempMockFileManager.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockGDTCoreTransport.h"
#import "Crashlytics/UnitTests/Mocks/FIRMockInstallations.h"

#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCPUExceptionDiagnostic.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCallStackTree.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXCrashDiagnostic.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXDiagnosticPayload.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXDiskWriteExceptionDiagnostic.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMXHangDiagnostic.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockMetricKitManager.h"

#define TEST_GOOGLE_APP_ID (@"1:632950151350:ios:d5b0d08d4f00f4b1")

@interface FIRCLSMetricKitManagerTests : XCTestCase

@property(nonatomic, strong) FIRCLSMockReportManager *reportManager;
@property(nonatomic, strong) FIRCLSMockMetricKitManager *metricKitManager;
@property(nonatomic, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, strong) FIRCLSMockReportUploader *mockReportUploader;
@property(nonatomic, strong) FIRCLSTempMockFileManager *fileManager;
@property(nonatomic, strong) FIRCLSExistingReportManager *existingReportManager;

@property(nonatomic, strong) FIRCLSDataCollectionArbiter *dataArbiter;
@property(nonatomic, strong) FIRCLSApplicationIdentifierModel *appIDModel;

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

  FIRCLSManagerData *managerData =
      [[FIRCLSManagerData alloc] initWithGoogleAppID:TEST_GOOGLE_APP_ID
                                     googleTransport:mockGoogleTransport
                                       installations:iid
                                           analytics:nil
                                         fileManager:self.fileManager
                                         dataArbiter:self.dataArbiter
                                            settings:mockSettings];

  self.mockReportUploader = [[FIRCLSMockReportUploader alloc] initWithManagerData:managerData];

  self.existingReportManager =
      [[FIRCLSExistingReportManager alloc] initWithManagerData:managerData
                                                reportUploader:self.mockReportUploader];

  self.metricKitManager =
      [[FIRCLSMockMetricKitManager alloc] initWithManagerData:managerData
                                        existingReportManager:self.existingReportManager
                                                  fileManager:self.fileManager];
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
      @" @{\"callStacks\":[{\"threadAttributed\":true,\"callStackRootFrames\":[{"
      @"\"offsetIntoBinaryTextSegment\":123,\"address\":74565,\"sampleCount\":20,\"binaryName\":"
      @"\"testBinaryName\",\"binaryUUID\":\"3C73DFD1-900D-4BDB-BBFA-11DFF7FC9B7C\"}]}],"
      @"\"callStackPerThread\":true}\"";
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
                exceptionType:@1
                exceptionCode:@0
                       signal:@11
                     metadata:[self createMockMetadata]
           applicationVersion:@"1"];
}

- (FIRCLSMockMXHangDiagnostic *)createHangDiagnostic {
  return [[FIRCLSMockMXHangDiagnostic alloc]
      initWithCallStackTree:[self createMockCallStackTree]
               hangDuration:[[NSMeasurement alloc] initWithDoubleValue:4.0
                                                                  unit:NSUnitDuration.seconds]
                   metadata:[self createMockMetadata]
         applicationVersion:@"1"];
}

- (FIRCLSMockMXCPUExceptionDiagnostic *)createCPUExceptionDiagnostic {
  return [[FIRCLSMockMXCPUExceptionDiagnostic alloc]
      initWithCallStackTree:[self createMockCallStackTree]
               totalCPUTime:[[NSMeasurement alloc] initWithDoubleValue:1.0
                                                                  unit:NSUnitDuration.seconds]
           totalSampledTime:[[NSMeasurement alloc] initWithDoubleValue:2.0
                                                                  unit:NSUnitDuration.seconds]
                   metadata:[self createMockMetadata]
         applicationVersion:@"1"];
}

- (FIRCLSMockMXDiskWriteExceptionDiagnostic *)createDiskWriteExcptionDiagnostic {
  return [[FIRCLSMockMXDiskWriteExceptionDiagnostic alloc]
      initWithCallStackTree:[self createMockCallStackTree]
          totalWritesCaused:[[NSMeasurement alloc] initWithDoubleValue:24.0
                                                                  unit:NSUnitDuration.seconds]
                   metadata:[self createMockMetadata]
         applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createCrashDiagnosticPayload {
  NSDictionary *diagnostics = @{@"crashes" : @[ [self createCrashDiagnostic] ]};
  NSDate *startTime = [NSDate init];
  NSDate *endTime = [NSDate init];
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:startTime
                                                       timeStampEnd:endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createHangDiagnosticPayload {
  NSDictionary *diagnostics = @{@"hangs" : @[ [self createHangDiagnostic] ]};
  NSDate *startTime = [NSDate init];
  NSDate *endTime = [NSDate init];
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:startTime
                                                       timeStampEnd:endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createCPUExceptionDiagnosticPayload {
  NSDictionary *diagnostics = @{@"cpuExceptions" : @[ [self createCPUExceptionDiagnostic] ]};
  NSDate *startTime = [NSDate init];
  NSDate *endTime = [NSDate init];
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:startTime
                                                       timeStampEnd:endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createDiskWriteExceptionDiagnosticPayload {
  NSDictionary *diagnostics =
      @{@"diskWriteExceptions" : @[ [self createDiskWriteExcptionDiagnostic] ]};
  NSDate *startTime = [NSDate init];
  NSDate *endTime = [NSDate init];
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:startTime
                                                       timeStampEnd:endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createFullDiagnosticPayload {
  NSDictionary *diagnostics = @{
    @"crashes" : @[ [self createCrashDiagnostic] ],
    @"hangs" : @[ [self createHangDiagnostic] ],
    @"cpuExceptions" : @[ [self createCPUExceptionDiagnostic] ],
    @"diskWriteExceptions" : @[ [self createDiskWriteExcptionDiagnostic] ]
  };
  NSDate *startTime = [NSDate init];
  NSDate *endTime = [NSDate init];
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:startTime
                                                       timeStampEnd:endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createEmptyDiagnosticPayload {
  NSDictionary *diagnostics = [[NSDictionary alloc] init];
  NSDate *startTime = [NSDate init];
  NSDate *endTime = [NSDate init];
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:startTime
                                                       timeStampEnd:endTime
                                                 applicationVersion:@"1"];
}

- (FIRCLSMockMXDiagnosticPayload *)createDiagnosticPayloadWithMultipleCrashes {
  NSDictionary *diagnostics = @{
    @"crashes" : @[
      [self createCrashDiagnostic], [self createCrashDiagnostic], [self createCrashDiagnostic]
    ]
  };
  NSDate *startTime = [NSDate init];
  NSDate *endTime = [NSDate init];
  return [[FIRCLSMockMXDiagnosticPayload alloc] initWithDiagnostics:diagnostics
                                                     timeStampBegin:startTime
                                                       timeStampEnd:endTime
                                                 applicationVersion:@"1"];
}

#pragma mark - Path Helpers
- (NSArray *)contentsOfActivePath {
  return [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.fileManager.activePath
                                                             error:nil];
}

- (BOOL)metricKitFileExists {
  return [[NSFileManager defaultManager]
      fileExistsAtPath:[self.fileManager.activePath
                           stringByAppendingString:@"metric_kit.clsrecord"]];
}

- (NSString *)contentsOfMetricKitFile {
  if (![self metricKitFileExists]) return nil;
  NSString *fileContents =
      [[NSString alloc] initWithContentsOfFile:[self.fileManager.activePath
                                                   stringByAppendingString:@"metric_kit.clsrecord"]
                                      encoding:NSUTF8StringEncoding
                                         error:nil];
  return fileContents;
}

- (NSDictionary *)contentsOfMetricKitFileAsDictionary {
  NSString *metricKitFileContents = [self contentsOfMetricKitFile];
  NSData *fileData = [metricKitFileContents dataUsingEncoding:NSUTF8StringEncoding];
  NSDictionary *fileDictionary = [NSJSONSerialization JSONObjectWithData:fileData
                                                                 options:0
                                                                   error:nil];
  return fileDictionary;
}

#pragma mark - Diagnostic Handling

- (void)testEmptyDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *emptyPayload = [self createEmptyDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ emptyPayload ]];
  XCTAssertFalse([self metricKitFileExists], "metric kit report should not exist");
}

- (void)testCrashDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *crashPayload = [self createCrashDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ crashPayload ]];
  XCTAssertTrue([self metricKitFileExists], "metric kit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary];
  XCTAssertNotNil(fileDictionary, "metric kit file should not be empty");
}

- (void)testHangDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *hangPayload = [self createHangDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ hangPayload ]];
  XCTAssertTrue([self metricKitFileExists], "metric kit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary];
  XCTAssertNotNil(fileDictionary, "metric kit file should not be empty");
}

- (void)testCPUExceptionDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *cpuPayload = [self createCPUExceptionDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ cpuPayload ]];
  XCTAssertTrue([self metricKitFileExists], "metric kit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary];
  XCTAssertNotNil(fileDictionary, "metric kit file should not be empty");
}

- (void)testDiskWriteExceptionDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *diskWritePayload =
      [self createDiskWriteExceptionDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ diskWritePayload ]];
  XCTAssertTrue([self metricKitFileExists], "metric kit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary];
  XCTAssertNotNil(fileDictionary, "metric kit file should not be empty");
}

- (void)testFullDiagnosticHandling {
  FIRCLSMockMXDiagnosticPayload *fullPayload = [self createFullDiagnosticPayload];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ fullPayload ]];
  XCTAssertTrue([self metricKitFileExists], "metric kit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary];
  XCTAssertNotNil(fileDictionary, "metric kit file should not be empty");
}

- (void)testPayloadWithMultipleCrashesHandling {
  FIRCLSMockMXDiagnosticPayload *payloadWithMultipleCrashes =
      [self createDiagnosticPayloadWithMultipleCrashes];
  [self.metricKitManager didReceiveDiagnosticPayloads:@[ payloadWithMultipleCrashes ]];
  XCTAssertTrue([self metricKitFileExists], "metric kit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary];
  XCTAssertNotNil(fileDictionary, "metric kit file should not be empty");
}

- (void)testMultiplePayloadsWithCrashesHandling {
  FIRCLSMockMXDiagnosticPayload *crashPayload = [self createCrashDiagnosticPayload];
  FIRCLSMockMXDiagnosticPayload *hangPayload = [self createHangDiagnosticPayload];
  FIRCLSMockMXDiagnosticPayload *cpuPayload = [self createCPUExceptionDiagnosticPayload];
  [self.metricKitManager
      didReceiveDiagnosticPayloads:@[ crashPayload, hangPayload, crashPayload, cpuPayload ]];
  XCTAssertTrue([self metricKitFileExists], "metric kit report should exist");

  NSDictionary *fileDictionary = [self contentsOfMetricKitFileAsDictionary];
  XCTAssertNotNil(fileDictionary, "metric kit file should not be empty");
}

@end
