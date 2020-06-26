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

#import <XCTest/XCTest.h>

#include "Crashlytics/third_party/libunwind/dwarf.h"

#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachO.h"

#include "Crashlytics/Crashlytics/Components/FIRCLSContext.h"
#include "Crashlytics/Crashlytics/Components/FIRCLSGlobals.h"
#include "Crashlytics/Crashlytics/Helpers/FIRCLSDefines.h"
#include "Crashlytics/Crashlytics/Unwind/Dwarf/FIRCLSDwarfUnwind.h"
#include "Crashlytics/Crashlytics/Unwind/FIRCLSUnwind_arch.h"

@interface FIRCLSDwarfTests : XCTestCase

@end

@implementation FIRCLSDwarfTests

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

#if CLS_DWARF_UNWINDING_SUPPORTED
#if CLS_CPU_X86_64

- (void)testParseDwarfUnwindInfoForobjc_msgSend_x86_64_1093 {
  NSString* dylibPath = [self pathForResource:@"10.9.3_libobjc.A.dylib"];

  struct FIRCLSMachOFile file;

  XCTAssertTrue(FIRCLSMachOFileInitWithPath(&file, [dylibPath fileSystemRepresentation]), @"");

  struct FIRCLSMachOSlice slice = FIRCLSMachOFileSliceWithArchitectureName(&file, "x86_64");

  FIRCLSMachOSection section;
  const void* ehFrame = NULL;

  FIRCLSMachOSliceInitSectionByName(&slice, SEG_TEXT, "__eh_frame", &section);

  // This computation is a little funny. Because we've just opened this dylib as a file,
  // the "slide" is really whereever the file ended up being mapped in memory.
  ehFrame = (void*)(section.addr + (uintptr_t)slice.startAddress);

  XCTAssertTrue(ehFrame != NULL, @"");

  FIRCLSDwarfCFIRecord record;

  // hard-code to the FDE offset for objc_msgSend
  XCTAssertTrue(FIRCLSDwarfParseCFIFromFDERecordOffset(&record, ehFrame, 0x00001a48), @"");

  // check the CIE record
  XCTAssertEqual(record.cie.length, 28, @"");
  XCTAssertEqual(record.cie.version, 3, @"");
  XCTAssertEqual(record.cie.ehData, 0, @"");
  XCTAssertEqualObjects([NSString stringWithUTF8String:record.cie.augmentation], @"zPR", @"");
  XCTAssertEqual(record.cie.pointerEncoding, DW_EH_PE_absptr | DW_EH_PE_pcrel, @"");
  XCTAssertEqual(record.cie.lsdaEncoding, DW_EH_PE_absptr, @"");
  XCTAssertEqual(record.cie.personalityEncoding,
                 DW_EH_PE_indirect | DW_EH_PE_pcrel | DW_EH_PE_sdata4, @"");
  XCTAssertEqual(record.cie.codeAlignFactor, 1, @"");
  XCTAssertEqual(record.cie.dataAlignFactor, -8, @"");
  XCTAssertEqual(record.cie.returnAddressRegister, 16, @"");
  XCTAssertEqual(record.cie.signalFrame, false, @"");
  XCTAssertTrue(FIRCLSDwarfCIEHasAugmentationData(&record.cie), @"");

  // check the FDE record
  XCTAssertEqual(record.fde.length, 44, @"");
  XCTAssertEqual(record.fde.cieOffset, 68, @"");
  XCTAssertEqual(record.fde.startAddress, (uintptr_t)slice.startAddress + 0x5080, @"");
  XCTAssertEqual(record.fde.rangeSize, 0x124, @"");

  FIRCLSMachOFileDestroy(&file);
}

#endif

- (void)testGetSavedRegisterWithInvalidValues {
  FIRCLSThreadContext registers;
  const FIRCLSDwarfRegister dRegister = {FIRCLSDwarfRegisterUnused, 0};

  XCTAssertEqual(FIRCLSDwarfGetSavedRegister(NULL, 0, dRegister), 0, @"");
  XCTAssertEqual(FIRCLSDwarfGetSavedRegister(&registers, 0, dRegister), 0, @"");
}

- (void)testGetSavedRegisterWithInCFA {
  uintptr_t memoryBuffer[2] = {45, 46};
  FIRCLSThreadContext registers;
  const FIRCLSDwarfRegister dRegister = {FIRCLSDwarfRegisterInCFA, sizeof(uintptr_t)};

  // this should compute *(memoryBuffer + sizeof(uintptr_t)) = 46
  XCTAssertEqual(FIRCLSDwarfGetSavedRegister(&registers, (uintptr_t)memoryBuffer, dRegister), 46,
                 @"");
}

- (void)testRegisterStructureSizingAndMaxValues {
  FIRCLSDwarfState state;

  XCTAssertEqual(sizeof(state.registers) / sizeof(FIRCLSDwarfRegister),
                 CLS_DWARF_MAX_REGISTER_NUM + 1,
                 @"Number of DWARF register values needs to match the max register size for the "
                 @"architecture, plus one");

  XCTAssertTrue(CLS_DWARF_MAX_REGISTER_NUM > 1);
  XCTAssertTrue(CLS_DWARF_INVALID_REGISTER_NUM > CLS_DWARF_MAX_REGISTER_NUM);
}

- (void)testAssignReturnRegisterNumber {
  FIRCLSDwarfState state;
  FIRCLSThreadContext inputRegisters;
  FIRCLSThreadContext outputRegisters;

  memset(&state, 0, sizeof(FIRCLSDwarfState));
  memset(&inputRegisters, 0, sizeof(FIRCLSThreadContext));
  memset(&outputRegisters, 0, sizeof(FIRCLSThreadContext));

  uintptr_t cfaRegister = 42;  // doesn't matter for this test

  // set the return register to live inside another reg, just for convenience
  state.registers[CLS_DWARF_REG_RETURN].location = FIRCLSDwarfRegisterInRegister;

  // Setup our arch-specific values. Be careful not to use the 0 register enum value
  // because that can artifically pass.
#if CLS_CPU_X86_64
  state.registers[CLS_DWARF_REG_RETURN].value = CLS_DWARF_X86_64_RDX;
  FIRCLSDwarfUnwindSetRegisterValue(&inputRegisters, CLS_DWARF_X86_64_RDX, 777);
#elif CLS_CPU_I386
  state.registers[CLS_DWARF_REG_RETURN].value = CLS_DWARF_X86_ECX;
  FIRCLSDwarfUnwindSetRegisterValue(&inputRegisters, CLS_DWARF_X86_ECX, 777);
#elif CLS_CPU_ARM64
  state.registers[CLS_DWARF_REG_RETURN].value = CLS_DWARF_ARM64_X1;
  FIRCLSDwarfUnwindSetRegisterValue(&inputRegisters, CLS_DWARF_ARM64_X1, 777);
#endif

  XCTAssertTrue(
      FIRCLSDwarfUnwindAssignRegisters(&state, &inputRegisters, cfaRegister, &outputRegisters));

  XCTAssertEqual(FIRCLSDwarfUnwindGetRegisterValue(&outputRegisters, CLS_DWARF_REG_RETURN), 777);
}

#endif

@end
