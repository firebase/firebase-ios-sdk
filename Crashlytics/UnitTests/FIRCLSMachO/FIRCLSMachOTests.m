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

#import "Crashlytics/UnitTests/FIRCLSMachO/FIRCLSMachOTests.h"

#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachO.h"

#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachOBinary.h"
#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachOSlice.h"
#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSdSYM.h"

@implementation FIRCLSMachOTests

- (NSString*)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSArray*)sortedArchitectures:(id)obj {
  NSMutableArray* archs;

  archs = [NSMutableArray array];
  [obj enumerateUUIDs:^(NSString* uuid, NSString* architecture) {
    [archs addObject:architecture];
  }];

  // sort the array, so we always get back the results in the same order
  [archs sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    return [obj1 caseInsensitiveCompare:obj2];
  }];

  return archs;
}

- (void)testThinDSYM {
  FIRCLSdSYM* dSYM;
  NSString* path;
  NSArray* archs;

  path = [[self resourcePath] stringByAppendingPathComponent:@"i386-simulator.dSYM"];
  dSYM = [FIRCLSdSYM dSYMWithURL:[NSURL fileURLWithPath:path]];
  archs = [self sortedArchitectures:dSYM];

  XCTAssertEqual((NSUInteger)1, [archs count], @"");
  XCTAssertEqualObjects(@"i386", [archs objectAtIndex:0], @"");
}

- (void)testFatDSYM {
  FIRCLSdSYM* dSYM;
  NSString* path;
  NSArray* archs;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7-armv7s.dSYM"];
  dSYM = [FIRCLSdSYM dSYMWithURL:[NSURL fileURLWithPath:path]];
  archs = [self sortedArchitectures:dSYM];

  XCTAssertEqual((NSUInteger)2, [archs count], @"");
  XCTAssertEqualObjects(@"armv7", [archs objectAtIndex:0], @"");
  XCTAssertEqualObjects(@"armv7s", [archs objectAtIndex:1], @"");
}

- (void)testFatExecutable {
  FIRCLSMachOBinary* binary;
  NSString* path;
  NSArray* archs;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7-armv7s-executable"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  archs = [self sortedArchitectures:binary];

  XCTAssertEqual((NSUInteger)2, [archs count], @"");
  XCTAssertEqualObjects(@"armv7", [archs objectAtIndex:0], @"");
  XCTAssertEqualObjects(@"armv7s", [archs objectAtIndex:1], @"");
}

- (void)testArm64 {
  FIRCLSMachOBinary* binary;
  NSString* path;
  NSArray* archs;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7-armv7s-arm64.dylib"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  archs = [self sortedArchitectures:binary];

  XCTAssertEqual((NSUInteger)3, [archs count], @"");
  XCTAssertEqualObjects(@"arm64", [archs objectAtIndex:0], @"");
  XCTAssertEqualObjects(@"armv7", [archs objectAtIndex:1], @"");
  XCTAssertEqualObjects(@"armv7s", [archs objectAtIndex:2], @"");
}

- (void)testArmv7k {
  FIRCLSMachOBinary* binary;
  NSString* path;
  NSArray* archs;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7k"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  archs = [self sortedArchitectures:binary];

  XCTAssertEqual((NSUInteger)1, [archs count], @"");
  XCTAssertEqualObjects(@"armv7k", [archs objectAtIndex:0], @"");
}

- (void)testReadMinimumWatchOSSDKRequirements {
  FIRCLSMachOBinary* binary;
  FIRCLSMachOSlice* slice;
  NSString* path;
  FIRCLSMachOVersion version;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7k"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  slice = [binary sliceForArchitecture:@"armv7k"];

  version = [slice minimumOSVersion];
  XCTAssertEqual((uint32_t)2, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");

  version = [slice linkedSDKVersion];
  XCTAssertEqual((uint32_t)2, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");
}

- (void)testReadMinimumWatchOSSimulatorSDKRequirements {
  FIRCLSMachOBinary* binary;
  FIRCLSMachOSlice* slice;
  NSString* path;
  FIRCLSMachOVersion version;

  path = [[self resourcePath] stringByAppendingPathComponent:@"watchOS-simulator"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  slice = [binary sliceForArchitecture:@"i386"];

  version = [slice minimumOSVersion];
  XCTAssertEqual((uint32_t)2, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");

  version = [slice linkedSDKVersion];
  XCTAssertEqual((uint32_t)2, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");
}

- (void)testReadMinimumTVOSSDKRequirements {
  FIRCLSMachOBinary* binary;
  FIRCLSMachOSlice* slice;
  NSString* path;
  FIRCLSMachOVersion version;

  path = [[self resourcePath] stringByAppendingPathComponent:@"tvos-binary"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  slice = [binary sliceForArchitecture:@"arm64"];

  version = [slice minimumOSVersion];
  XCTAssertEqual((uint32_t)8, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");

  version = [slice linkedSDKVersion];
  XCTAssertEqual((uint32_t)9, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");
}

- (void)testReadMinimumTVOSSimulatorSDKRequirements {
  FIRCLSMachOBinary* binary;
  FIRCLSMachOSlice* slice;
  NSString* path;
  FIRCLSMachOVersion version;

  path = [[self resourcePath] stringByAppendingPathComponent:@"tvsimulator-binary"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  slice = [binary sliceForArchitecture:@"x86_64"];

  version = [slice minimumOSVersion];
  XCTAssertEqual((uint32_t)8, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");

  version = [slice linkedSDKVersion];
  XCTAssertEqual((uint32_t)9, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");
}

- (void)testLinkedDylibs {
  FIRCLSMachOBinary* binary;
  FIRCLSMachOSlice* slice;
  NSString* path;
  NSArray* dylibs;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7-armv7s-executable"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  slice = [binary sliceForArchitecture:@"armv7"];

  XCTAssertNotNil(slice, @"");

  dylibs = [[slice linkedDylibs] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
    return [obj1 compare:obj2 options:NSCaseInsensitiveSearch];
  }];

  XCTAssertEqual([dylibs count], (NSUInteger)7, @"");
  XCTAssertEqualObjects([dylibs objectAtIndex:0],
                        @"/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation", @"");
  XCTAssertEqualObjects([dylibs objectAtIndex:1],
                        @"/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", @"");
  XCTAssertEqualObjects([dylibs objectAtIndex:2],
                        @"/System/Library/Frameworks/Foundation.framework/Foundation", @"");
  XCTAssertEqualObjects([dylibs objectAtIndex:3],
                        @"/System/Library/Frameworks/UIKit.framework/UIKit", @"");
  XCTAssertEqualObjects([dylibs objectAtIndex:4], @"/usr/lib/libobjc.A.dylib", @"");
  XCTAssertEqualObjects([dylibs objectAtIndex:5], @"/usr/lib/libstdc++.6.dylib", @"");
  XCTAssertEqualObjects([dylibs objectAtIndex:6], @"/usr/lib/libSystem.B.dylib", @"");
}

- (void)testReadMinimumiOSSDKRequirements {
  FIRCLSMachOBinary* binary;
  FIRCLSMachOSlice* slice;
  NSString* path;
  FIRCLSMachOVersion version;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7-armv7s-executable"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  slice = [binary sliceForArchitecture:@"armv7"];

  version = [slice minimumOSVersion];
  XCTAssertEqual((uint32_t)5, version.major, @"");
  XCTAssertEqual((uint32_t)1, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");

  version = [slice linkedSDKVersion];
  XCTAssertEqual((uint32_t)6, version.major, @"");
  XCTAssertEqual((uint32_t)0, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");
}

- (void)testReadMinimumOSXSDKRequirements {
  FIRCLSMachOBinary* binary;
  FIRCLSMachOSlice* slice;
  NSString* path;
  FIRCLSMachOVersion version;

  path = [[self resourcePath] stringByAppendingPathComponent:@"x86_64-executable"];
  binary = [FIRCLSMachOBinary MachOBinaryWithPath:path];
  slice = [binary sliceForArchitecture:@"x86_64"];

  version = [slice minimumOSVersion];
  XCTAssertEqual((uint32_t)10, version.major, @"");
  XCTAssertEqual((uint32_t)7, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");

  version = [slice linkedSDKVersion];
  XCTAssertEqual((uint32_t)10, version.major, @"");
  XCTAssertEqual((uint32_t)8, version.minor, @"");
  XCTAssertEqual((uint32_t)0, version.bugfix, @"");
}

- (void)testReadx86_64Section {
  NSString* path = [[self resourcePath] stringByAppendingPathComponent:@"x86_64-executable"];
  struct FIRCLSMachOFile file;

  XCTAssert(FIRCLSMachOFileInitWithPath(&file, [path fileSystemRepresentation]));

  struct FIRCLSMachOSlice slice = FIRCLSMachOFileSliceWithArchitectureName(&file, "x86_64");

  XCTAssert(FIRCLSMachOSliceIs64Bit(&slice));

  FIRCLSMachOSection section;
  XCTAssert(FIRCLSMachOSliceInitSectionByName(&slice, SEG_TEXT, "__eh_frame", &section));
  XCTAssertEqual(section.addr, 0x10001c9e0);
  XCTAssertEqual(section.offset, 117216);
  XCTAssertEqual(section.size, 0x2618);

  const void* ptr = NULL;
  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__eh_frame", &ptr));
  XCTAssert(ptr != NULL);
}

- (void)testReadArmv7kSection {
  NSString* path = [[self resourcePath] stringByAppendingPathComponent:@"armv7k"];
  struct FIRCLSMachOFile file;

  XCTAssert(FIRCLSMachOFileInitWithPath(&file, [path fileSystemRepresentation]));

  struct FIRCLSMachOSlice slice = FIRCLSMachOFileSliceWithArchitectureName(&file, "armv7k");

  FIRCLSMachOSection section;
  XCTAssert(FIRCLSMachOSliceInitSectionByName(&slice, SEG_TEXT, "__unwind_info", &section));
  XCTAssertEqual(section.addr, 0x23c4c);
  XCTAssertEqual(section.offset, 130124);
  XCTAssertEqual(section.size, 0x000002d8);

  const void* ptr = NULL;
  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__unwind_info", &ptr));
  XCTAssert(ptr != NULL);
}

- (void)testReadArm64Section {
  NSString* path = [[self resourcePath] stringByAppendingPathComponent:@"armv7-armv7s-arm64.dylib"];
  struct FIRCLSMachOFile file;

  XCTAssert(FIRCLSMachOFileInitWithPath(&file, [path fileSystemRepresentation]));

  struct FIRCLSMachOSlice slice = FIRCLSMachOFileSliceWithArchitectureName(&file, "arm64");

  XCTAssert(FIRCLSMachOSliceIs64Bit(&slice));

  FIRCLSMachOSection section;
  XCTAssert(FIRCLSMachOSliceInitSectionByName(&slice, SEG_TEXT, "__unwind_info", &section));
  XCTAssertEqual(section.addr, 0x1ffa9);
  XCTAssertEqual(section.offset, 130985);
  XCTAssertEqual(section.size, 0x48);

  const void* ptr = NULL;
  XCTAssert(FIRCLSMachOSliceGetSectionByName(&slice, SEG_TEXT, "__unwind_info", &ptr));
  XCTAssert(ptr != NULL);
}

@end
