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

/// It is important that crashes do not occur when reading persisted crash files before uploading
/// Verify various invalid input cases
- (void)testInvalidRecordCases {
  id adapter __unused = [[FIRCLSReportAdapter alloc] initWithPath:@"nonExistentPath"
                                                      googleAppId:@"appID"];

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
}

/// It is important that crashes do not occur when reading persisted crash files before uploading
/// Verify various invalid input cases
- (void)testCorruptRecordCases {
  id adapter __unused = [FIRCLSReportAdapterTests adapterForCorruptFiles];
}

- (void)testRecordBinaryImagesFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidFiles];
  XCTAssertEqual(adapter.binaryImages.count, 453);

  // Verify first binary
  FIRCLSRecordBinaryImage *firstImage = adapter.binaryImages[0];
  XCTAssertTrue([firstImage.path
      isEqualToString:
          @"/private/var/containers/Bundle/Application/C49F1179-0088-4882-A60D-13ACDA2AF8B3/"
          @"Crashlytics-iOS-App.app/Crashlytics-iOS-App"]);
  XCTAssertTrue([firstImage.uuid isEqualToString:@"0341c4166f253830a94a5698cee7fea7"]);
  XCTAssertEqual(firstImage.base, 4305256448);
  XCTAssertEqual(firstImage.size, 1392640);

  // Verify last binary
  FIRCLSRecordBinaryImage *lastImage = adapter.binaryImages[452];
  XCTAssertTrue(
      [lastImage.path isEqualToString:@"/System/Library/Frameworks/Accelerate.framework/Frameworks/"
                                      @"vImage.framework/Libraries/libCGInterfaces.dylib"]);
  XCTAssertTrue([lastImage.uuid isEqualToString:@"f4421e9313fa386fbd568035eb1d35be"]);
  XCTAssertEqual(lastImage.base, 7226896384);
  XCTAssertEqual(lastImage.size, 86016);
}

- (void)testRecordMetadataFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidFiles];

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

  // Verify executable
  XCTAssertTrue([adapter.executable.architecture isEqualToString:@"arm64"]);
  XCTAssertTrue([adapter.executable.uuid isEqualToString:@"0341c4166f253830a94a5698cee7fea7"]);
  XCTAssertEqual(adapter.executable.base, 4305256448);
  XCTAssertEqual(adapter.executable.size, 1392640);
}

- (void)testRecordInternalKeyValueFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidFiles];
  XCTAssertEqual(adapter.internalKeyValues.count, 6);

  // Verify first
  XCTAssertTrue([adapter.internalKeyValues[@"com.crashlytics.in-background"] isEqualToString:@"0"]);

  // Verify last
  XCTAssertTrue([adapter.internalKeyValues[@"com.crashlytics.user-id"]
      isEqualToString:@"test-user-28AE6E09-BC30-4CB3-9FA5-FE06828B8F3C"]);
}

- (void)testRecordUserKeyValueFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidFiles];
  XCTAssertEqual(adapter.userKeyValues.count, 3);

  // Verify first
  XCTAssertTrue([adapter.userKeyValues[@"some_key_1"] isEqualToString:@"some_value_1"]);

  // Verify last
  XCTAssertTrue([adapter.userKeyValues[@"some_key_3"] isEqualToString:@"some_value_3"]);
}

- (void)testRecordUserLogFiles {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidFiles];
  XCTAssertEqual(adapter.userLogs.count, 6);

  // Verify first
  XCTAssertTrue([adapter.userLogs[0].msg isEqualToString:@"custom_log_msg_1"]);
  XCTAssertEqual(adapter.userLogs[0].time, 1579796958175);

  // Verify last
  XCTAssertTrue([adapter.userLogs[5].msg  isEqualToString:@"custom_log_msg_6"]);
  XCTAssertEqual(adapter.userLogs[5].time, 1579796959935);
}

- (void)testRecordSignalFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidFiles];

  // Verify signal
  XCTAssertEqual(adapter.signal.number, 6);
  XCTAssertEqual(adapter.signal.code, 0);
  XCTAssertEqual(adapter.signal.address, 7020687100);
  XCTAssertTrue([adapter.signal.name isEqualToString:@"SIGABRT"]);
  XCTAssertTrue([adapter.signal.code_name isEqualToString:@"ABORT"]);
  XCTAssertEqual(adapter.signal.err_no, 0);
  XCTAssertEqual(adapter.signal.time, 1579796965);

  // Verify threads
  XCTAssertEqual(adapter.threads.count, 6);

  FIRCLSRecordThread *firstThread = adapter.threads[0];
  XCTAssertEqual(firstThread.crashed, true);
  XCTAssertNil(firstThread.name);
  XCTAssertTrue(
      [firstThread.objc_selector_name isEqualToString:@"some_selector"]);  // Verifies runtime too
  XCTAssertTrue([firstThread.alternate_name
      isEqualToString:@"com.apple.main-thread"]);  // Verify dispatch queue names too
  XCTAssertEqual(firstThread.registers.count, 34);
  XCTAssertTrue([firstThread.registers[0].name isEqualToString:@"x21"]);
  XCTAssertEqual(firstThread.registers[0].value, 4309358880);
  XCTAssertTrue([firstThread.registers[33].name isEqualToString:@"x1"]);
  XCTAssertEqual(firstThread.registers[33].value, 0);

  FIRCLSRecordThread *lastThread = adapter.threads[5];
  XCTAssertEqual(lastThread.crashed, false);
  XCTAssertTrue(
      [lastThread.name isEqualToString:@"com.google.firebase.crashlytics.MachExceptionServer"]);
  XCTAssertNil(lastThread.objc_selector_name);
  XCTAssertNil(lastThread.alternate_name);
  XCTAssertEqual(lastThread.registers.count, 34);
  XCTAssertTrue([lastThread.registers[0].name isEqualToString:@"x21"]);
  XCTAssertEqual(lastThread.registers[0].value, 42247);
  XCTAssertTrue([lastThread.registers[33].name isEqualToString:@"x1"]);
  XCTAssertEqual(lastThread.registers[33].value, 6);

  // Verify process stats
  XCTAssertEqual(adapter.processStats.active, 847511552);
  XCTAssertEqual(adapter.processStats.inactive, 810123264);
  XCTAssertEqual(adapter.processStats.wired, 712228864);
  XCTAssertEqual(adapter.processStats.freeMem, 97353728);
  XCTAssertEqual(adapter.processStats.virtualAddress, 5046468608);
  XCTAssertEqual(adapter.processStats.resident, 847511552);
  XCTAssertEqual(adapter.processStats.user_time, 30829);
  XCTAssertEqual(adapter.processStats.sys_time, 0);

  // Verify storage
  XCTAssertEqual(adapter.storage.free, 9388113920);
  XCTAssertEqual(adapter.storage.total, 63989469184);
}

- (void)testProtoReport {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForValidFiles];
  __unused NSData *report = [adapter transportBytes];

  // TODO - Consider: take a dependency on protobuf in tests and compare the nanopb generated bytes
  //                  vs. canonical protobuf bytes
}

- (void)testProtoReportFromCorruptFiles {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForCorruptFiles];
  __unused NSData *report = [adapter transportBytes];
}

// Helper functions

+ (FIRCLSReportAdapter *)adapterForValidFiles {
  return [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests persistedCrashFolder]
                                       googleAppId:@"appID"];
}

+ (FIRCLSReportAdapter *)adapterForCorruptFiles {
  return [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests corruptedCrashFolder]
                                       googleAppId:@"appID"];
}

+ (NSString *)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

+ (NSString *)persistedCrashFolder {
  return [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"ios_crash"];
}

+ (NSString *)corruptedCrashFolder {
  return [[FIRCLSReportAdapterTests resourcePath] stringByAppendingPathComponent:@"corrupt_files"];
}

@end
