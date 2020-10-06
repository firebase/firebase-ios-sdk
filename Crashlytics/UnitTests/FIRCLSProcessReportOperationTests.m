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

#import "Crashlytics/Crashlytics/Operations/Reports/FIRCLSProcessReportOperation.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Crashlytics/Helpers/FIRCLSFile.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSFileManager.h"
#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"
#import "Crashlytics/Crashlytics/Private/FIRStackFrame_Private.h"
#import "Crashlytics/UnitTests/Mocks/FIRCLSMockSymbolResolver.h"

@interface FIRCLSProcessReportOperationTests : XCTestCase

@end

@implementation FIRCLSProcessReportOperationTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the
  // class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSString *)pathForResource:(NSString *)name {
  return [[self resourcePath] stringByAppendingPathComponent:name];
}

- (FIRCLSInternalReport *)createReportAndPath {
  NSString *reportPath =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"execution_identifier"];
  FIRCLSInternalReport *report =
      [[FIRCLSInternalReport alloc] initWithPath:reportPath
                             executionIdentifier:@"execution_identifier"];

  // create the directory path
  assert([[NSFileManager defaultManager] createDirectoryAtPath:[report path]
                                   withIntermediateDirectories:YES
                                                    attributes:nil
                                                         error:nil]);
  return report;
}

#if TARGET_OS_IPHONE
#else
- (void)testExceptionSymbolication {
  // Setup a resolver that will work for the contents of the file
  FIRCLSMockSymbolResolver *resolver = [[FIRCLSMockSymbolResolver alloc] init];

  FIRStackFrame *frame = nil;

  frame = [FIRStackFrame stackFrameWithSymbol:@"testSymbolA"];
  [frame setLibrary:@"libA"];
  [frame setOffset:10];

  [resolver addMockFrame:frame atAddress:4321599284];

  // create a report and symbolicate
  FIRCLSInternalReport *report = [self createReportAndPath];
  NSFileManager *fileManager = [NSFileManager defaultManager];

  // put an exception in place
  XCTAssertTrue([fileManager copyItemAtPath:[self pathForResource:FIRCLSReportExceptionFile]
                                     toPath:[report pathForContentFile:FIRCLSReportExceptionFile]
                                      error:nil],
                @"");

  FIRCLSProcessReportOperation *operation =
      [[FIRCLSProcessReportOperation alloc] initWithReport:report resolver:resolver];

  [operation start];

  // Read the symbolicated output and verify
  NSArray *sections = FIRCLSFileReadSections(
      [[report pathForContentFile:@"exception.clsrecord.symbolicated"] fileSystemRepresentation],
      false, nil);

  XCTAssertEqual([sections count], 1, @"");
  XCTAssertEqualObjects(sections[0][@"threads"][0][0][@"library"], @"libA", @"");
  XCTAssertEqualObjects(sections[0][@"threads"][0][0][@"offset"], @(10), @"");
  XCTAssertEqualObjects(sections[0][@"threads"][0][0][@"symbol"], @"testSymbolA", @"");
}
#endif

@end
