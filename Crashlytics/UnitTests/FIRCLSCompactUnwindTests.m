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

#include "Crashlytics/Crashlytics/Unwind/Compact/FIRCLSCompactUnwind.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachO.h"

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Unwind/Compact/FIRCLSCompactUnwind_Private.h"
#include "Crashlytics/Crashlytics/Unwind/FIRCLSUnwind_x86.h"

@interface FIRCLSCompactUnwindTests : XCTestCase

@end

@implementation FIRCLSCompactUnwindTests

- (void)setUp {
  [super setUp];

  _firclsContext.readonly = malloc(sizeof(FIRCLSReadOnlyContext));
  _firclsContext.readonly->logPath = "/tmp/test.log";
}

- (void)tearDown {
  [super tearDown];
}

- (NSString*)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSString*)pathForResource:(NSString*)name {
  return [[self resourcePath] stringByAppendingPathComponent:name];
}

#if CLS_COMPACT_UNWINDING_SUPPORTED

#if !TARGET_OS_IPHONE
- (void)testParseCompactUnwindInfoForthread_get_state_10_9_4 {
  NSString* dylibPath = [self pathForResource:@"10.9.4_libsystem_kernel.dylib"];

  struct FIRCLSMachOFile file;

  XCTAssertTrue(FIRCLSMachOFileInitWithPath(&file, [dylibPath fileSystemRepresentation]), @"");

  struct FIRCLSMachOSlice slice = FIRCLSMachOFileSliceWithArchitectureName(&file, "x86_64");

  const void* compactUnwind = NULL;
  const void* ehFrame = NULL;

  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__eh_frame", &ehFrame));
  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__unwind_info", &compactUnwind));

  XCTAssertTrue(ehFrame != NULL, @"");
  XCTAssertTrue(compactUnwind != NULL, @"");

  FIRCLSCompactUnwindContext context;

  // hard-code a load address seen during testing
  uintptr_t loadAddress = 0x7fff94044000;
  XCTAssertTrue(FIRCLSCompactUnwindInit(&context, compactUnwind, ehFrame, loadAddress), @"");

  FIRCLSCompactUnwindResult result;

  XCTAssertTrue(FIRCLSCompactUnwindLookup(&context, 0x7fff94051e6c, &result), @"");
  XCTAssertEqual(result.encoding & UNWIND_X86_64_MODE_MASK, UNWIND_X86_64_MODE_RBP_FRAME, @"");
  XCTAssertEqual(result.functionStart, loadAddress + 0x0000DCC1, @"");
}

- (void)testParseCompactUnwindInfoForFunctionInLastIndexEntry {
  NSString* dylibPath = [self pathForResource:@"10.9.4_libsystem_kernel.dylib"];

  struct FIRCLSMachOFile file;

  XCTAssertTrue(FIRCLSMachOFileInitWithPath(&file, [dylibPath fileSystemRepresentation]), @"");

  struct FIRCLSMachOSlice slice = FIRCLSMachOFileSliceWithArchitectureName(&file, "x86_64");

  const void* compactUnwind = NULL;
  const void* ehFrame = NULL;

  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__eh_frame", &ehFrame));
  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__unwind_info", &compactUnwind));

  XCTAssertTrue(ehFrame != NULL, @"");
  XCTAssertTrue(compactUnwind != NULL, @"");

  FIRCLSCompactUnwindContext context;

  // hard-code a load address seen during testing
  uintptr_t loadAddress = 0x7fff94044000;
  XCTAssertTrue(FIRCLSCompactUnwindInit(&context, compactUnwind, ehFrame, loadAddress), @"");

  FIRCLSCompactUnwindResult result;

  // there should be no entry here (0x00016FDE maps to the last index entry, 0x00016FDF)
  XCTAssertFalse(FIRCLSCompactUnwindLookup(&context, loadAddress + 0x00016FDE, &result), @"");
}

- (void)testParseCompactUnwindInfoForBoundaryBetween2ndLevelEntries {
  NSString* dylibPath = [self pathForResource:@"10.9.4_libsystem_kernel.dylib"];

  struct FIRCLSMachOFile file;

  XCTAssertTrue(FIRCLSMachOFileInitWithPath(&file, [dylibPath fileSystemRepresentation]), @"");

  struct FIRCLSMachOSlice slice = FIRCLSMachOFileSliceWithArchitectureName(&file, "x86_64");

  const void* compactUnwind = NULL;
  const void* ehFrame = NULL;

  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__eh_frame", &ehFrame));
  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__unwind_info", &compactUnwind));

  XCTAssertTrue(ehFrame != NULL, @"");
  XCTAssertTrue(compactUnwind != NULL, @"");

  FIRCLSCompactUnwindContext context;

  // hard-code a load address seen during testing
  uintptr_t loadAddress = 0x7fff94044000;
  XCTAssertTrue(FIRCLSCompactUnwindInit(&context, compactUnwind, ehFrame, loadAddress), @"");

  FIRCLSCompactUnwindResult result;

  // funcOffset=0x0000151A _reallocf
  // funcOffset=0x00001558 __pthread_exit_if_canceled

  // make sure we hit the last byte of _reallocf
  XCTAssertTrue(FIRCLSCompactUnwindLookup(&context, loadAddress + 0x00001557, &result), @"");
  XCTAssertEqual(result.encoding & UNWIND_X86_64_MODE_MASK, UNWIND_X86_64_MODE_RBP_FRAME, @"");
  XCTAssertEqual(result.functionStart, loadAddress + 0x0000151A, @"");
  XCTAssertEqual(result.functionEnd, loadAddress + 0x00001558, @"");

  // and check the very next value, which should be in __pthread_exit_if_canceled
  XCTAssertTrue(FIRCLSCompactUnwindLookup(&context, loadAddress + 0x00001558, &result), @"");
  XCTAssertEqual(result.encoding & UNWIND_X86_64_MODE_MASK, UNWIND_X86_64_MODE_DWARF, @"");
  XCTAssertEqual(result.functionStart, loadAddress + 0x00001558, @"");
}
#endif

#if CLS_CPU_X86_64
- (void)testComputeDirectStackSize {
  const compact_unwind_encoding_t encoding = 0x20a1860;
  const intptr_t functionStart = 0x0;

  uint32_t stackSize = 0;
  XCTAssertTrue(FIRCLSCompactUnwindComputeStackSize(encoding, functionStart, false, &stackSize),
                @"");

  // 0x20a1860 & 0x00FF0000 = 0xA0000
  // 0x270000 >> 16 = 0xA
  // 0xA * 8 = 0x50
  XCTAssertEqual(stackSize, 0x50, @"");
}
#endif

#endif

@end
