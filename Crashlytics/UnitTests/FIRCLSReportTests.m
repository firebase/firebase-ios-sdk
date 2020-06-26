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
#import "Crashlytics/Crashlytics/Models/FIRCLSReport.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSReport_Private.h"

@interface FIRCLSReportTests : XCTestCase

@end

@implementation FIRCLSReportTests

- (void)setUp {
  [super setUp];

  FIRCLSContextBaseInit();

  // these values must be set for the internals of logging to work
  _firclsContext.readonly->logging.userKVStorage.maxCount = 16;
  _firclsContext.readonly->logging.userKVStorage.maxIncrementalCount = 16;
  _firclsContext.readonly->logging.internalKVStorage.maxCount = 32;
  _firclsContext.readonly->logging.internalKVStorage.maxIncrementalCount = 16;

  _firclsContext.readonly->initialized = true;
}

- (void)tearDown {
  FIRCLSContextBaseDeinit();

  [super tearDown];
}

- (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
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

- (FIRCLSReport *)createTempCopyOfReportWithName:(NSString *)name {
  FIRCLSInternalReport *internalReport = [self createTempCopyOfInternalReportWithName:name];

  return [[FIRCLSReport alloc] initWithInternalReport:internalReport];
}

#pragma mark - Public Getter Methods
- (void)testPropertiesFromMetadatFile {
  FIRCLSReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  XCTAssertEqualObjects(@"772929a7f21f4ad293bb644668f257cd", report.identifier);
  XCTAssertEqualObjects(@"3", report.bundleVersion);
  XCTAssertEqualObjects(@"1.0", report.bundleShortVersionString);
  XCTAssertEqualObjects([NSDate dateWithTimeIntervalSince1970:1423944888], report.dateCreated);
  XCTAssertEqualObjects(@"14C109", report.OSBuildVersion);
  XCTAssertEqualObjects(@"10.10.2", report.OSVersion);
}

#pragma mark - Public Setter Methods
- (void)testSetUserProperties {
  FIRCLSReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  [report setUserIdentifier:@"12345-6"];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportInternalIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 1, @"");

  XCTAssertEqualObjects(entries[0][@"kv"][@"key"],
                        FIRCLSFileHexEncodeString([FIRCLSUserIdentifierKey UTF8String]), @"");
  XCTAssertEqualObjects(entries[0][@"kv"][@"value"], FIRCLSFileHexEncodeString("12345-6"), @"");
}

- (void)testSetKeyValuesWhenNoneWerePresent {
  FIRCLSReport *report = [self createTempCopyOfReportWithName:@"metadata_only_report"];

  [report setObjectValue:@"hello" forKey:@"mykey"];
  [report setObjectValue:@"goodbye" forKey:@"anotherkey"];

  NSArray *entries = FIRCLSFileReadSections(
      [[report.internalReport pathForContentFile:FIRCLSReportUserIncrementalKVFile]
          fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([entries count], 2, @"");

  // mykey = "..."
  XCTAssertEqualObjects(entries[0][@"kv"][@"key"], FIRCLSFileHexEncodeString("mykey"), @"");
  XCTAssertEqualObjects(entries[0][@"kv"][@"value"], FIRCLSFileHexEncodeString("hello"), @"");

  // anotherkey = "..."
  XCTAssertEqualObjects(entries[1][@"kv"][@"key"], FIRCLSFileHexEncodeString("anotherkey"), @"");
  XCTAssertEqualObjects(entries[1][@"kv"][@"value"], FIRCLSFileHexEncodeString("goodbye"), @"");
}

@end
