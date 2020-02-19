// Copyright 2020 Google
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

#import "FIRCLSRecordApplication.h"
#import "FIRCLSRecordBase.h"
#import "FIRCLSRecordBinaryImage.h"
#import "FIRCLSRecordExecutable.h"
#import "FIRCLSRecordFrame.h"
#import "FIRCLSRecordHost.h"
#import "FIRCLSRecordIdentity.h"
#import "FIRCLSRecordKeyValue.h"
#import "FIRCLSRecordProcessStats.h"
#import "FIRCLSRecordRegister.h"
#import "FIRCLSRecordRuntime.h"
#import "FIRCLSRecordSignal.h"
#import "FIRCLSRecordStorage.h"
#import "FIRCLSRecordThread.h"
#import "FIRCLSReportAdapter.h"
#import "FIRCLSReportAdapter_Private.h"

#import "FIRCLSFile.h"

#import <GoogleDataTransport/GDTCOREvent.h>
#import <GoogleDataTransport/GDTCORTargets.h>
#import <GoogleDataTransport/GDTCORTransport.h>

@interface FIRCLSReportAdapterTests : XCTestCase

@end

@implementation FIRCLSReportAdapterTests

/// Attempt sending a proto report to the reporting endpoint
- (void)testSendProtoReport {
  NSString *minCrash =
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"bare_min_crash"];

  FIRCLSReportAdapter *adapter =
      [[FIRCLSReportAdapter alloc] initWithPath:minCrash
                                    googleAppId:@"1:17586535263:ios:83778f4dc7e8a26ef794ea"
                                          orgId:@"5bec84f69ea6961d03000dc5"];

  GDTCORTransport *transport = [[GDTCORTransport alloc] initWithMappingID:@"1206"
                                                             transformers:nil
                                                                   target:kGDTCORTargetCSH];
  GDTCOREvent *event = [transport eventForTransport];
  event.dataObject = adapter;
  event.qosTier = GDTCOREventQoSFast;  // Bypass batching and have the event get sent out ASAP
  [transport sendDataEvent:event];
}

/// This test is useful for testing the binary output of the proto message
- (void)testProtoOutput {
  NSString *minCrash =
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"bare_min_crash"];

  FIRCLSReportAdapter *adapter = [[FIRCLSReportAdapter alloc] initWithPath:minCrash
                                                               googleAppId:@"appID"
                                                                     orgId:@"orgID"];

  NSData *data = adapter.transportBytes;

  NSError *error = nil;
  NSString *outputPath =
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"output.proto"];

  [data writeToFile:outputPath options:NSDataWritingAtomic error:&error];
  NSLog(@"Output path: %@", outputPath);

  if (error) {
    NSLog(@"Write returned error: %@", [error localizedDescription]);
  }

  // But a breakpoint here to copy the file from the output path.
}

#pragma mark - Adapter Values

/// It is important that crashes do not occur when reading persisted crash files before uploading
/// Verify various invalid input cases
- (void)testInvalidRecordCases {
  id adapter __unused = [[FIRCLSReportAdapter alloc] initWithPath:@"nonExistentPath"
                                                      googleAppId:@"appID"
                                                            orgId:@"orgID"];

  id application __unused = [[FIRCLSRecordApplication alloc] initWithDict:nil];
  id base __unused = [[FIRCLSRecordBase alloc] initWithDict:nil];
  id binaryImage __unused = [[FIRCLSRecordBinaryImage alloc] initWithDict:nil];
  id executable __unused = [[FIRCLSRecordExecutable alloc] initWithDict:nil];
  id frame __unused = [[FIRCLSRecordFrame alloc] initWithDict:nil];
  id host __unused = [[FIRCLSRecordHost alloc] initWithDict:nil];
  id identity __unused = [[FIRCLSRecordIdentity alloc] initWithDict:nil];
  id keyValues __unused = [[FIRCLSRecordKeyValue alloc] initWithDict:nil];
  id processStats __unused = [[FIRCLSRecordProcessStats alloc] initWithDict:nil];
  id reg __unused = [[FIRCLSRecordRegister alloc] initWithDict:nil];
  id runtime __unused = [[FIRCLSRecordRuntime alloc] initWithDict:nil];
  id signal __unused = [[FIRCLSRecordSignal alloc] initWithDict:nil];
  id storage __unused = [[FIRCLSRecordStorage alloc] initWithDict:nil];
  id thread __unused = [[FIRCLSRecordThread alloc] initWithDict:nil];
  id error __unused = [[FIRCLSRecordError alloc] initWithDict:nil];
  id exception __unused = [[FIRCLSRecordException alloc] initWithDict:nil];
  id mach_exception __unused = [[FIRCLSRecordMachException alloc] initWithDict:nil];

  NSDictionary *emptyDict = [[NSDictionary alloc] init];
  id application2 __unused = [[FIRCLSRecordApplication alloc] initWithDict:emptyDict];
  id base2 __unused = [[FIRCLSRecordBase alloc] initWithDict:emptyDict];
  id binaryImage2 __unused = [[FIRCLSRecordBinaryImage alloc] initWithDict:emptyDict];
  id executable2 __unused = [[FIRCLSRecordExecutable alloc] initWithDict:emptyDict];
  id frame2 __unused = [[FIRCLSRecordFrame alloc] initWithDict:emptyDict];
  id host2 __unused = [[FIRCLSRecordHost alloc] initWithDict:emptyDict];
  id identity2 __unused = [[FIRCLSRecordIdentity alloc] initWithDict:emptyDict];
  id keyValues2 __unused = [[FIRCLSRecordKeyValue alloc] initWithDict:emptyDict];
  id processStats2 __unused = [[FIRCLSRecordProcessStats alloc] initWithDict:emptyDict];
  id reg2 __unused = [[FIRCLSRecordRegister alloc] initWithDict:emptyDict];
  id runtime2 __unused = [[FIRCLSRecordRuntime alloc] initWithDict:emptyDict];
  id signal2 __unused = [[FIRCLSRecordSignal alloc] initWithDict:emptyDict];
  id storage2 __unused = [[FIRCLSRecordStorage alloc] initWithDict:emptyDict];
  id thread2 __unused = [[FIRCLSRecordThread alloc] initWithDict:emptyDict];
  id error2 __unused = [[FIRCLSRecordError alloc] initWithDict:emptyDict];
  id exception2 __unused = [[FIRCLSRecordException alloc] initWithDict:emptyDict];
  id mach_exception2 __unused = [[FIRCLSRecordMachException alloc] initWithDict:emptyDict];
}

/// It is important that crashes do not occur when reading persisted crash files before uploading
/// Verify various invalid input cases
- (void)testCorruptRecordCases {
  id adapter __unused = [FIRCLSReportAdapterTests adapterForCorruptFiles];
}

- (void)testRecordMetadataFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];

  // Verify identity
  XCTAssertTrue([adapter.identity.generator isEqualToString:@"Crashlytics iOS SDK/4.0.0-beta.1"]);
  XCTAssertTrue([adapter.identity.display_version isEqualToString:@"4.0.0-beta.1"]);
  XCTAssertTrue([adapter.identity.build_version isEqualToString:@"4.0.0-beta.1"]);
  XCTAssertEqual(adapter.identity.started_at, 1579796954);
  XCTAssertTrue([adapter.identity.session_id isEqualToString:@"f6cdb3f99e6f4c20a4d68a08c35e7b36"]);
  XCTAssertTrue(
      [adapter.identity.install_id isEqualToString:@"169DB25B-8F1D-4115-8364-3887DA9DE73C"]);

  // Verify host
  XCTAssertTrue([adapter.host.model isEqualToString:@"iPhone11,8"]);
  XCTAssertTrue([adapter.host.machine isEqualToString:@"N841AP"]);
  XCTAssertTrue([adapter.host.os_build_version isEqualToString:@"17C54"]);
  XCTAssertTrue([adapter.host.os_display_version isEqualToString:@"13.3.0"]);
  XCTAssertTrue([adapter.host.platform isEqualToString:@"ios"]);
  XCTAssertTrue([adapter.host.locale isEqualToString:@"en_US"]);

  // Verify application
  XCTAssertTrue(
      [adapter.application.bundle_id isEqualToString:@"com.google.crashlytics.app.ios-host"]);
  XCTAssertTrue([adapter.application.build_version isEqualToString:@"1"]);
  XCTAssertTrue([adapter.application.display_version isEqualToString:@"1.0"]);
}

// Helper functions
#pragma mark - Helper Functions

+ (FIRCLSReportAdapter *)adapterForExceptionCrash {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[FIRCLSReportAdapterTests persistedExceptionCrashFolder]
       googleAppId:@"appID"
             orgId:@"orgID"];
}

+ (FIRCLSReportAdapter *)adapterForMachExceptionCrash {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[FIRCLSReportAdapterTests persistedMachExceptionCrashFolder]
       googleAppId:@"appID"
             orgId:@"orgID"];
}

+ (FIRCLSReportAdapter *)adapterForSignalCrash {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[FIRCLSReportAdapterTests persistedSignalCrashFolder]
       googleAppId:@"appID"
             orgId:@"orgID"];
}

+ (FIRCLSReportAdapter *)adapterForAllCrashes {
  return
      [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests persistedAllCrashesFolder]
                                    googleAppId:@"appID"
                                          orgId:@"orgID"];
}

+ (FIRCLSReportAdapter *)adapterForOnlyErrors {
  return
      [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests persistedOnlyErrorsFolder]
                                    googleAppId:@"appID"
                                          orgId:@"orgID"];
}

+ (FIRCLSReportAdapter *)adapterForCorruptFiles {
  return [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests corruptedCrashFolder]
                                       googleAppId:@"appID"
                                             orgId:@"orgID"];
}

+ (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

+ (NSString *)persistedExceptionCrashFolder {
  return [[FIRCLSReportAdapterTests resourcePath]
      stringByAppendingPathComponent:@"ios_exception_crash"];
}

+ (NSString *)persistedMachExceptionCrashFolder {
  return [[FIRCLSReportAdapterTests resourcePath]
      stringByAppendingPathComponent:@"ios_mach_exception_crash"];
}

+ (NSString *)persistedSignalCrashFolder {
  return
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"ios_signal_crash"];
}

+ (NSString *)persistedAllCrashesFolder {
  return [[FIRCLSReportAdapterTests resourcePath]
      stringByAppendingPathComponent:@"ios_all_files_crash"];
}

+ (NSString *)persistedOnlyErrorsFolder {
  return
      [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"ios_only_errors"];
}

+ (NSString *)corruptedCrashFolder {
  return [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"corrupt_files"];
}

@end
