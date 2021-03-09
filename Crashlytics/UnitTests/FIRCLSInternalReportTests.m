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

#import "Crashlytics/Crashlytics/Models/FIRCLSInternalReport.h"

#import <XCTest/XCTest.h>

@interface FIRCLSInternalReportTests : XCTestCase

@end

@implementation FIRCLSInternalReportTests

- (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSString *)pathForResource:(NSString *)name {
  return [[self resourcePath] stringByAppendingPathComponent:name];
}

- (void)testCustomExceptionsNeedToBeSubmitted {
  NSString *name = @"metadata_only_report";

  NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:name];

  // make sure to remove anything that was there previously
  [[NSFileManager defaultManager] removeItemAtPath:tempPath error:nil];

  NSString *resourcePath = [self pathForResource:name];

  [[NSFileManager defaultManager] copyItemAtPath:resourcePath toPath:tempPath error:nil];

  FIRCLSInternalReport *report = [[FIRCLSInternalReport alloc] initWithPath:tempPath];

  NSString *customAPath = [report pathForContentFile:FIRCLSReportCustomExceptionAFile];
  NSString *customBPath = [report pathForContentFile:FIRCLSReportCustomExceptionBFile];

  XCTAssertFalse(report.hasAnyEvents, @"metadata only should not need to be submitted");

  [[NSFileManager defaultManager] createFileAtPath:customAPath
                                          contents:[NSData data]
                                        attributes:nil];

  XCTAssert(report.hasAnyEvents, @"with the A file present, needs to be submitted");

  [[NSFileManager defaultManager] createFileAtPath:customBPath
                                          contents:[NSData data]
                                        attributes:nil];

  // with A and B, also needs
  XCTAssert(report.hasAnyEvents, @"with both the A and B files present, needs to be submitted");

  XCTAssert([[NSFileManager defaultManager] removeItemAtPath:customAPath error:nil]);
  XCTAssert(report.hasAnyEvents, @"with the B file present, needs to be submitted");
}

@end
