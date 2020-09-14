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

#import "Crashlytics/UnitTests/FIRCLSMachO/FIRCLSMachOBinaryTests.h"

#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSMachOBinary.h"

@implementation FIRCLSMachOBinaryTests

- (NSString*)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (NSURL*)URLForResource:(NSString*)resource {
  NSString* path;

  path = [[self resourcePath] stringByAppendingPathComponent:resource];

  return [NSURL fileURLWithPath:path];
}

- (void)testInstanceIdentifierForSingleArchdSYM {
  FIRCLSMachOBinary* binary;

  binary = [[FIRCLSMachOBinary alloc] initWithURL:[self URLForResource:@"x86_64-executable"]];

  XCTAssertEqualObjects([binary instanceIdentifier], @"442eb836efe1f56bf8a65b2a0a78b2f8d3e792e7",
                        @"");
}

- (void)testInstanceIdentifierForMultipleArchitectures {
  FIRCLSMachOBinary* binary;

  binary = [[FIRCLSMachOBinary alloc] initWithURL:[self URLForResource:@"armv7-armv7s-executable"]];

  XCTAssertEqualObjects([binary instanceIdentifier], @"80cc0ec0af8a0169831abcc73177eb2b57990bc0",
                        @"");
}

@end
