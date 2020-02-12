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

#pragma mark - Adapter Values

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

- (void)testRecordBinaryImagesFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];
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

  // Verify executable
  XCTAssertTrue([adapter.executable.architecture isEqualToString:@"arm64"]);
  XCTAssertTrue([adapter.executable.uuid isEqualToString:@"0341c4166f253830a94a5698cee7fea7"]);
  XCTAssertEqual(adapter.executable.base, 4305256448);
  XCTAssertEqual(adapter.executable.size, 1392640);
}

- (void)testRecordInternalKeyValueFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];
  XCTAssertEqual(adapter.internalKeyValues.count, 6);

  // Verify first
  XCTAssertTrue([adapter.internalKeyValues[@"com.crashlytics.in-background"] isEqualToString:@"0"]);

  // Verify last
  XCTAssertTrue([adapter.internalKeyValues[@"com.crashlytics.user-id"]
      isEqualToString:@"test-user-28AE6E09-BC30-4CB3-9FA5-FE06828B8F3C"]);
}

- (void)testRecordUserKeyValueFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];
  XCTAssertEqual(adapter.userKeyValues.count, 3);

  // Verify first
  XCTAssertTrue([adapter.userKeyValues[@"some_key_1"] isEqualToString:@"some_value_1"]);

  // Verify last
  XCTAssertTrue([adapter.userKeyValues[@"some_key_3"] isEqualToString:@"some_value_3"]);
}

- (void)testRecordUserLogFiles {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];
  XCTAssertEqual(adapter.userLogs.count, 6);

  // Verify first
  XCTAssertTrue([adapter.userLogs[0].msg isEqualToString:@"custom_log_msg_1"]);
  XCTAssertEqual(adapter.userLogs[0].time, 1579796958175);

  // Verify last
  XCTAssertTrue([adapter.userLogs[5].msg isEqualToString:@"custom_log_msg_6"]);
  XCTAssertEqual(adapter.userLogs[5].time, 1579796959935);
}

- (void)testRecordUserErrorFiles {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];
  XCTAssertEqual(adapter.errors.count, 4);

  // Verify first
  XCTAssertTrue([adapter.errors[0].domain isEqualToString:@"Crashlytics_App.CustomSwiftError1"]);
  XCTAssertEqual(adapter.errors[0].code, 0);
  XCTAssertEqual(adapter.errors[0].time, 1579796960);

  XCTAssertEqual(adapter.errors[0].stacktrace.count, 29);
  XCTAssertEqual(adapter.errors[0].stacktrace[0].unsignedIntegerValue, 4305958120);
  XCTAssertEqual(adapter.errors[0].stacktrace[28].unsignedIntegerValue, 7020727832);

  // Verify last
  XCTAssertTrue([adapter.errors[3].domain isEqualToString:@"Crashlytics_App.CustomSwiftError4"]);
  XCTAssertEqual(adapter.errors[3].code, 4);
  XCTAssertEqual(adapter.errors[3].time, 1579796966);

  XCTAssertEqual(adapter.errors[3].stacktrace.count, 29);
  XCTAssertEqual(adapter.errors[3].stacktrace[0].unsignedIntegerValue, 4305958121);
  XCTAssertEqual(adapter.errors[3].stacktrace[28].unsignedIntegerValue, 7020727833);
}

- (void)testRecordSignalFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];

  // The other types of crashes should be nil for a signal crash
  XCTAssertNil(adapter.exception);
  XCTAssertNil(adapter.mach_exception);
  XCTAssertTrue(adapter.hasCrashed);

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

- (void)testRecordExceptionFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForExceptionCrash];

  // The other types of crashes should be nil for a signal crash
  XCTAssertNil(adapter.mach_exception);
  XCTAssertNil(adapter.signal);
  XCTAssertTrue(adapter.hasCrashed);

  XCTAssertTrue(
      [adapter.exception.name isEqualToString:@"46696c654e6f74466f756e64457863657074696f6e"]);
  XCTAssertTrue([adapter.exception.reason
      isEqualToString:@"46696c65204e6f7420466f756e64206f6e2053797374656d"]);
  XCTAssertTrue([adapter.exception.type isEqualToString:@"objective-c"]);
  XCTAssertEqual(adapter.exception.time, 1580850620);

  XCTAssertEqual(adapter.exception.frames.count, 14);

  XCTAssertEqual(adapter.exception.frames[0].line, 405);
  XCTAssertTrue(adapter.exception.frames[0].hasLine);
  XCTAssertEqual(adapter.exception.frames[0].offset, 101);
  XCTAssertTrue(adapter.exception.frames[0].hasOffset);
  XCTAssertEqual(adapter.exception.frames[0].pc, 140733792821726);
  XCTAssertNil(adapter.exception.frames[0].symbol);

  XCTAssertEqual(adapter.exception.frames[13].line, 2003);
  XCTAssertTrue(adapter.exception.frames[13].hasLine);
  XCTAssertEqual(adapter.exception.frames[13].offset, 1203);
  XCTAssertTrue(adapter.exception.frames[13].hasOffset);
  XCTAssertEqual(adapter.exception.frames[13].pc, 140734559604009);
  XCTAssertNil(adapter.exception.frames[13].symbol);

  // Verify threads
  XCTAssertEqual(adapter.threads.count, 12);

  FIRCLSRecordThread *firstThread = adapter.threads[0];
  XCTAssertEqual(firstThread.crashed, true);
  XCTAssertNil(firstThread.name);
  XCTAssertNil(firstThread.objc_selector_name);
  XCTAssertTrue([firstThread.alternate_name
      isEqualToString:@"com.google.firebase.crashlytics.ios.exception"]);
  XCTAssertTrue([firstThread.registers[0].name isEqualToString:@"r13"]);
  XCTAssertEqual(firstThread.registers[0].value, 101);
  XCTAssertTrue([firstThread.registers[20].name isEqualToString:@"rdi"]);
  XCTAssertEqual(firstThread.registers[20].value, 0);

  FIRCLSRecordThread *lastThread = adapter.threads[11];
  XCTAssertEqual(lastThread.crashed, false);
  XCTAssertTrue([lastThread.name isEqualToString:@"com.apple.NSURLConnectionLoader"]);
  XCTAssertNil(lastThread.objc_selector_name);
  XCTAssertNil(lastThread.alternate_name);
  XCTAssertEqual(lastThread.registers.count, 21);

  XCTAssertTrue([lastThread.registers[0].name isEqualToString:@"r13"]);
  XCTAssertEqual(lastThread.registers[0].value, 3072);
  XCTAssertTrue([lastThread.registers[20].name isEqualToString:@"rdi"]);
  XCTAssertEqual(lastThread.registers[20].value, 123145416097712);

  // Verify process stats
  XCTAssertEqual(adapter.processStats.active, 11547275264);
  XCTAssertEqual(adapter.processStats.inactive, 11312398336);
  XCTAssertEqual(adapter.processStats.wired, 7626276864);
  XCTAssertEqual(adapter.processStats.freeMem, 268677120);
  XCTAssertEqual(adapter.processStats.virtualAddress, 6019653632);
  XCTAssertEqual(adapter.processStats.resident, 11547275264);
  XCTAssertEqual(adapter.processStats.user_time, 0);
  XCTAssertEqual(adapter.processStats.sys_time, 100);

  // Verify storage
  XCTAssertEqual(adapter.storage.free, 163940671488);
  XCTAssertEqual(adapter.storage.total, 499963174912);
}

- (void)testRecordMachExceptionFile {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForMachExceptionCrash];

  // The other types of crashes should be nil for a signal crash
  XCTAssertNil(adapter.exception);
  XCTAssertNil(adapter.signal);
  XCTAssertTrue(adapter.hasCrashed);

  XCTAssertTrue([adapter.mach_exception.name isEqualToString:@"EXC_BAD_ACCESS"]);
  XCTAssertTrue([adapter.mach_exception.code_name isEqualToString:@"KERN_INVALID_ADDRESS"]);
  XCTAssertEqual(adapter.mach_exception.exception, 1);
  XCTAssertEqual(adapter.mach_exception.original_ports, 2);
  XCTAssertEqual(adapter.mach_exception.codes.count, 2);
  XCTAssertEqual([adapter.mach_exception.codes[0] unsignedIntValue], 1);
  XCTAssertEqual([adapter.mach_exception.codes[1] unsignedIntValue], 32);

  XCTAssertEqual(adapter.mach_exception.time, 1581375422);

  // Verify threads in a very basic way (since other tests cover this)
  XCTAssertEqual(adapter.threads.count, 7);

  FIRCLSRecordThread *firstThread = adapter.threads[0];
  XCTAssertEqual(firstThread.crashed, true);
  XCTAssertNil(firstThread.name);
  XCTAssertNil(firstThread.objc_selector_name);
  XCTAssertTrue([firstThread.alternate_name isEqualToString:@"com.apple.main-thread"]);
  XCTAssertTrue([firstThread.registers[0].name isEqualToString:@"r13"]);
  XCTAssertEqual(firstThread.registers[0].value, 105553125228976);
  XCTAssertTrue([firstThread.registers[20].name isEqualToString:@"rdi"]);
  XCTAssertEqual(firstThread.registers[20].value, 105553116266546);

  FIRCLSRecordThread *lastThread = adapter.threads[6];
  XCTAssertEqual(lastThread.crashed, false);
  XCTAssertTrue([lastThread.name isEqualToString:@"com.apple.NSURLConnectionLoader"]);
  XCTAssertNil(lastThread.objc_selector_name);
  XCTAssertNil(lastThread.alternate_name);
  XCTAssertEqual(lastThread.registers.count, 21);

  XCTAssertTrue([lastThread.registers[0].name isEqualToString:@"r13"]);
  XCTAssertEqual(lastThread.registers[0].value, 3072);
  XCTAssertTrue([lastThread.registers[20].name isEqualToString:@"rdi"]);
  XCTAssertEqual(lastThread.registers[20].value, 123145560817584);

  // Verify process stats in a very basic way (since other tests cover this)
  XCTAssertEqual(adapter.processStats.active, 11934932992);
  XCTAssertEqual(adapter.processStats.virtualAddress, 6428303360);
  XCTAssertEqual(adapter.processStats.user_time, 91691);
  XCTAssertEqual(adapter.processStats.sys_time, 133815);

  // Verify storage
  XCTAssertEqual(adapter.storage.free, 155774451712);
  XCTAssertEqual(adapter.storage.total, 499963174912);
}

#pragma mark - Proto Report Values

// If there's just a signal file, use it to determine the fields in the crash event's
// signal field
- (void)testSignalOnlyProtoReportSignalFields {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];
  google_crashlytics_Report reportProto = [adapter report];
  google_crashlytics_Session_Event lastEventProto = [self getLastEventProto:reportProto];

  google_crashlytics_Session_Event_Application_Execution_Signal signalProto =
      lastEventProto.app.execution.signal;

  XCTAssertTrue(reportProto.session.crashed);

  XCTAssertEqual(signalProto.address, 7020687100);
  [self assertPBData:signalProto.code isEqualToString:@"ABORT"];
  [self assertPBData:signalProto.name isEqualToString:@"SIGABRT"];
}

// If there's both a Mach Exception and Signal file, the Mach Exception file takes precedence
// to set the signal fields in the crash event
- (void)testAllCrashesProtoReportSignalFields {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForAllCrashes];
  google_crashlytics_Report reportProto = [adapter report];
  google_crashlytics_Session_Event lastEventProto = [self getLastEventProto:reportProto];

  google_crashlytics_Session_Event_Application_Execution_Signal signalProto =
      lastEventProto.app.execution.signal;

  XCTAssertTrue(reportProto.session.crashed);

  XCTAssertEqual(signalProto.address, 32);
  [self assertPBData:signalProto.code isEqualToString:@"KERN_INVALID_ADDRESS"];
  [self assertPBData:signalProto.name isEqualToString:@"EXC_BAD_ACCESS"];
}

// The order of precedence is Exception > Mach Exception > Signal. This test
// ensures that common attributes of each of those files is applied with the right
// precedence
- (void)testAllCrashesProtoReportPrecedence {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForAllCrashes];
  google_crashlytics_Report reportProto = [adapter report];
  google_crashlytics_Session_Event lastEventProto = [self getLastEventProto:reportProto];

  // Process stats, disk space, and threads should be from the Exception file
  XCTAssertEqual(reportProto.session.device.ram, 11547275264 + 11312398336 + 7626276864);

  XCTAssertEqual(reportProto.session.device.disk_space, 499963174912);
  XCTAssertEqual(lastEventProto.device.disk_used, 499963174912 - 163940671488);

  XCTAssertEqual(lastEventProto.app.execution.threads_count, 12);
}

// If there's just errors, make sure things line up
- (void)testErrorsOnlyProtoReport {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForOnlyErrors];
  google_crashlytics_Report reportProto = [adapter report];

  XCTAssertFalse(reportProto.session.crashed);

  XCTAssertEqual(reportProto.session.events_count, 4);

  // Sanity check some fields
  for (int i = 0; i < reportProto.session.events_count; i++) {
    google_crashlytics_Session_Event event = reportProto.session.events[i];
    XCTAssert(event.timestamp > 0);
    XCTAssertEqual(event.app.execution.threads_count, 1);
    XCTAssert(event.app.execution.threads[0].frames[0].pc != 0);
  }

  XCTAssertEqual(reportProto.session.events[0].timestamp, 1579796960);
  XCTAssertEqual(reportProto.session.events[0].app.execution.threads[0].frames[0].pc, 4305958120);

  XCTAssertEqual(reportProto.session.events[3].timestamp, 1579796966);
  XCTAssertEqual(reportProto.session.events[3].app.execution.threads[0].frames[3].pc, 4305600396);
  XCTAssertEqual(reportProto.session.events[3].app.execution.threads[0].frames[28].pc, 7020727833);
}

#pragma mark - Proto Report Bytes

- (void)testExceptionProtoReportBytes {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForExceptionCrash];
  __unused NSData *report = [adapter transportBytes];

  // TODO - Consider: take a dependency on protobuf in tests and compare the nanopb generated bytes
  //                  vs. canonical protobuf bytes
}

- (void)testMachExceptionProtoReportBytes {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForMachExceptionCrash];
  __unused NSData *report = [adapter transportBytes];

  // TODO - Consider: take a dependency on protobuf in tests and compare the nanopb generated bytes
  //                  vs. canonical protobuf bytes
}

- (void)testSignalProtoReportBytes {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForSignalCrash];
  __unused NSData *report = [adapter transportBytes];

  // TODO - Consider: take a dependency on protobuf in tests and compare the nanopb generated bytes
  //                  vs. canonical protobuf bytes
}

- (void)testProtoReportFromCorruptFilesBytes {
  FIRCLSReportAdapter *adapter = [FIRCLSReportAdapterTests adapterForCorruptFiles];
  __unused NSData *report = [adapter transportBytes];
}

#pragma mark - Assertion Helpers for NanoPB Types

- (void)assertPBData:(pb_bytes_array_t *)pbString isEqualToString:(NSString *)expected {
  pb_bytes_array_t *expectedProtoBytes = FIRCLSEncodeString(expected);
  XCTAssertEqual(pbString->size, expectedProtoBytes->size);

  for (int i = 0; i < pbString->size; i++) {
    XCTAssertEqual(expectedProtoBytes->bytes[i], pbString->bytes[i]);
  }
}

#pragma mark - Getting Portions of the Proto

- (google_crashlytics_Session_Event)getLastEventProto:(google_crashlytics_Report)reportProto {
  XCTAssert(reportProto.session.events_count > 0);
  return reportProto.session.events[reportProto.session.events_count - 1];
}

// Helper functions
#pragma mark - Helper Functions

+ (FIRCLSReportAdapter *)adapterForExceptionCrash {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[FIRCLSReportAdapterTests persistedExceptionCrashFolder]
       googleAppId:@"appID"];
}

+ (FIRCLSReportAdapter *)adapterForMachExceptionCrash {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[FIRCLSReportAdapterTests persistedMachExceptionCrashFolder]
       googleAppId:@"appID"];
}

+ (FIRCLSReportAdapter *)adapterForSignalCrash {
  return [[FIRCLSReportAdapter alloc]
      initWithPath:[FIRCLSReportAdapterTests persistedSignalCrashFolder]
       googleAppId:@"appID"];
}

+ (FIRCLSReportAdapter *)adapterForAllCrashes {
  return
      [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests persistedAllCrashesFolder]
                                    googleAppId:@"appID"];
}

+ (FIRCLSReportAdapter *)adapterForOnlyErrors {
  return
      [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests persistedOnlyErrorsFolder]
                                    googleAppId:@"appID"];
}

+ (FIRCLSReportAdapter *)adapterForCorruptFiles {
  return [[FIRCLSReportAdapter alloc] initWithPath:[FIRCLSReportAdapterTests corruptedCrashFolder]
                                       googleAppId:@"appID"];
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
