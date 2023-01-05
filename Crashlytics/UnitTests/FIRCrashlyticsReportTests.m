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

#import "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#import "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#import "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRCrashlyticsReport_Private.h"
#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlyticsReport.h"

@interface FIRCrashlyticsReportTests : XCTestCase

@end

@implementation FIRCrashlyticsReportTests

- (void)setUp {
  [super setUp];

  FIRCLSContextBaseInit();

  // these values must be set for the internals of logging to work
  _firclsContext.readonly->logging.userKVStorage.maxCount = 64;
  _firclsContext.readonly->logging.userKVStorage.maxIncrementalCount =
      FIRCLSUserLoggingMaxKVEntries;
  _firclsContext.readonly->logging.internalKVStorage.maxCount = 32;
  _firclsContext.readonly->logging.internalKVStorage.maxIncrementalCount = 16;

  _firclsContext.readonly->logging.logStorage.maxSize = 64 * 1000;
  _firclsContext.readonly->logging.logStorage.maxEntries = 0;
  _firclsContext.readonly->logging.logStorage.restrictBySize = true;
  _firclsContext.readonly->logging.logStorage.entryCount = NULL;

  _firclsContext.readonly->initialized = true;
}

- (void)tearDown {
  FIRCLSContextBaseDeinit();

  [super tearDown];
}

- (NSString *)resourcePath {
#if SWIFT_PACKAGE
  NSBundle *bundle = SWIFTPM_MODULE_BUNDLE;
  return [bundle.resourcePath stringByAppendingPathComponent:@"Data"];
#else
  NSBundle *bundle = [NSBundle bundleForClass:[self class]];
  return bundle.resourcePath;
#endif
}

- (NSString *)pathForResource:(NSString *)name {
  return [[self resourcePath] stringByAppendingPathComponent:name];
}

- (FIRCLSInternalReport *)createTempCopyOfInternalReportWithName:(NSString *)name {
  NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:name];

  // make sure to remove anything that was there previously
  [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

  NSString *resourcePath = [self pathForResource:name];

  [[NSFileManager defaultManager] copyItemAtPath:resourcePath toPath:tempPath error:nil];

  return [[FIRCLSInternalReport alloc] initWithPath:tempPath];
}

- (FIRCrashlyticsReport *)createTempCopyOfReportWithName:(NSString *)name {
  FIRCLSInternalReport *internalReport = [self createTempCopyOfInternalReportWithName:name];
  return [[FIRCrashlyticsReport alloc] initWithInternalReport:internalReport];
}

#pragma mark - Public Getter Methods
- (void)testPropertiesFromMetadatFile {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  XCTAssertEqualObjects(@"772929a7f21f4ad293bb644668f257cd", report.reportID);
  XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:1423944888], report.dateCreated);
}

#pragma mark - Public Setter Methods
- (void)testSetUserID {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  [report setUserID:@"12345-6"];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportInternalIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 1, @"");

  XCTAssertEqualObjects(entries[0][@"kv"][@"key"],
                        FIRCLSFileHexEncodeString([FIRCLSUserIdentifierKey UTF8String]), @"");
  XCTAssertEqualObjects(entries[0][@"kv"][@"value"], FIRCLSFileHexEncodeString("12345-6"), @"");
}

- (void)testClearUserID {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  // Add a user ID
  [report setUserID:@"12345-6"];
  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportInternalIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 1, @"");

  // Now remove it
  [report setUserID:nil];

  entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportInternalCompactedKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 0, @"");
}

- (void)testCustomKeysNoExisting {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  [report setCustomValue:@"hello" forKey:@"mykey"];
  [report setCustomValue:@"goodbye" forKey:@"anotherkey"];

  [report setCustomKeysAndValues:@{
    @"is_test" : @(YES),
    @"test_number" : @(10),
  }];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 4, @"");

  XCTAssertEqualObjects(entries[0][@"kv"][@"key"], FIRCLSFileHexEncodeString("mykey"), @"");
  XCTAssertEqualObjects(entries[0][@"kv"][@"value"], FIRCLSFileHexEncodeString("hello"), @"");

  XCTAssertEqualObjects(entries[1][@"kv"][@"key"], FIRCLSFileHexEncodeString("anotherkey"), @"");
  XCTAssertEqualObjects(entries[1][@"kv"][@"value"], FIRCLSFileHexEncodeString("goodbye"), @"");

  XCTAssertEqualObjects(entries[2][@"kv"][@"key"], FIRCLSFileHexEncodeString("is_test"), @"");
  XCTAssertEqualObjects(entries[2][@"kv"][@"value"], FIRCLSFileHexEncodeString("1"), @"");

  XCTAssertEqualObjects(entries[3][@"kv"][@"key"], FIRCLSFileHexEncodeString("test_number"), @"");
  XCTAssertEqualObjects(entries[3][@"kv"][@"value"], FIRCLSFileHexEncodeString("10"), @"");
}

- (void)testCustomKeysWithExisting {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"ios_all_files_crash"];

  [report setCustomValue:@"hello" forKey:@"mykey"];
  [report setCustomValue:@"goodbye" forKey:@"anotherkey"];

  [report setCustomKeysAndValues:@{
    @"is_test" : @(YES),
    @"test_number" : @(10),
  }];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 5, @"");

  XCTAssertEqualObjects(entries[1][@"kv"][@"key"], FIRCLSFileHexEncodeString("mykey"), @"");
  XCTAssertEqualObjects(entries[1][@"kv"][@"value"], FIRCLSFileHexEncodeString("hello"), @"");

  XCTAssertEqualObjects(entries[2][@"kv"][@"key"], FIRCLSFileHexEncodeString("anotherkey"), @"");
  XCTAssertEqualObjects(entries[2][@"kv"][@"value"], FIRCLSFileHexEncodeString("goodbye"), @"");

  XCTAssertEqualObjects(entries[3][@"kv"][@"key"], FIRCLSFileHexEncodeString("is_test"), @"");
  XCTAssertEqualObjects(entries[3][@"kv"][@"value"], FIRCLSFileHexEncodeString("1"), @"");

  XCTAssertEqualObjects(entries[4][@"kv"][@"key"], FIRCLSFileHexEncodeString("test_number"), @"");
  XCTAssertEqualObjects(entries[4][@"kv"][@"value"], FIRCLSFileHexEncodeString("10"), @"");
}

- (void)testClearCustomKeys {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  // Add keys
  [report setCustomValue:@"hello" forKey:@"mykey"];
  [report setCustomValue:@"goodbye" forKey:@"anotherkey"];

  [report setCustomKeysAndValues:@{
    @"is_test" : @(YES),
    @"test_number" : @(10),
  }];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 4, @"");

  // Now remove them
  [report setCustomValue:nil forKey:@"mykey"];
  [report setCustomValue:nil forKey:@"anotherkey"];
  entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);
  [report setCustomKeysAndValues:@{
    @"is_test" : [NSNull null],
    @"test_number" : [NSNull null],
  }];

  entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportInternalCompactedKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 0, @"");
}

- (void)testCustomKeysLimits {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"ios_all_files_crash"];

  // Write a bunch of keys and values
  for (int i = 0; i < 120; i++) {
    NSString *key = [NSString stringWithFormat:@"key_%i", i];
    [report setCustomValue:@"hello" forKey:key];
  }

  NSArray *entriesI = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);
  NSArray *entriesC = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserCompactedKVFile]
          fileSystemRepresentation],
      false, nil);

  // One of these should be the max (64), and one should be the number of written keys modulo 64
  // (eg. 56 == (120 mod 64))
  XCTAssertEqual(entriesI.count, 56, @"");
  XCTAssertEqual(entriesC.count, 64, @"");
}

- (void)testLogsNoExisting {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  [report log:@"Normal log without formatting"];
  [report logWithFormat:@"%@, %@", @"First", @"Second"];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportLogAFile] fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 2, @"");

  XCTAssertEqualObjects(entries[0][@"log"][@"msg"],
                        FIRCLSFileHexEncodeString("Normal log without formatting"), @"");
  XCTAssertEqualObjects(entries[1][@"log"][@"msg"], FIRCLSFileHexEncodeString("First, Second"),
                        @"");
}

- (void)testLogsWithExisting {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"ios_all_files_crash"];

  [report log:@"Normal log without formatting"];
  [report logWithFormat:@"%@, %@", @"First", @"Second"];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportLogAFile] fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 8, @"");

  XCTAssertEqualObjects(entries[6][@"log"][@"msg"],
                        FIRCLSFileHexEncodeString("Normal log without formatting"), @"");
  XCTAssertEqualObjects(entries[7][@"log"][@"msg"], FIRCLSFileHexEncodeString("First, Second"),
                        @"");
}

- (void)testLogLimits {
  FIRCrashlyticsReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  for (int i = 0; i < 2000; i++) {
    [report log:@"0123456789"];
  }

  unsigned long long sizeA = [[[NSFileManager defaultManager]
      attributesOfItemAtPath:[report.internalReport pathForContentFile:FIRCLSReportLogAFile]
                       error:nil] fileSize];
  unsigned long long sizeB = [[[NSFileManager defaultManager]
      attributesOfItemAtPath:[report.internalReport pathForContentFile:FIRCLSReportLogBFile]
                       error:nil] fileSize];

  NSArray *entriesA = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportLogAFile] fileSystemRepresentation],
      false, nil);
  NSArray *entriesB = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportLogBFile] fileSystemRepresentation],
      false, nil);

  // If these numbers have changed, the goal is to validate that the size of log_a and log_b are
  // under the limit, logStorage.maxSize (64 * 1000). These numbers don't need to be exact so if
  // they fluctuate then we might just need to accept a range in these tests.
  XCTAssertEqual(entriesB.count + entriesA.count, 2000, @"");
  XCTAssertEqual(sizeA, 64 * 1000 + 20, @"");
  XCTAssertEqual(sizeB, 55980, @"");
}

@end
