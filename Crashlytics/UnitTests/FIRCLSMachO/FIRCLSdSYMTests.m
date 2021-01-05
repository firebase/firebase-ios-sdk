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

#import "Crashlytics/UnitTests/FIRCLSMachO/FIRCLSdSYMTests.h"

#import "Crashlytics/Shared/FIRCLSMachO/FIRCLSdSYM.h"

@implementation FIRCLSdSYMTests

- (NSString*)resourcePath {
  return [[NSBundle bundleForClass:[self class]] resourcePath];
}

- (void)testBundleIdAndExecutablePath {
  FIRCLSdSYM* dSYM;
  NSString* path;

  path = [[self resourcePath] stringByAppendingPathComponent:@"i386-simulator.dSYM"];
  dSYM = [FIRCLSdSYM dSYMWithURL:[NSURL fileURLWithPath:path]];

  XCTAssertEqualObjects(@"com.crashlytics.ios.CrashTest", [dSYM bundleIdentifier], @"");
  XCTAssertTrue([[dSYM executablePath] hasSuffix:@"CrashTest"], @"");
}

- (void)testUUIDsInFatFile {
  FIRCLSdSYM* dSYM;
  NSString* path;
  NSMutableDictionary* uuids;

  path = [[self resourcePath] stringByAppendingPathComponent:@"armv7-armv7s.dSYM"];
  dSYM = [FIRCLSdSYM dSYMWithURL:[NSURL fileURLWithPath:path]];

  uuids = [NSMutableDictionary dictionary];
  [dSYM enumerateUUIDs:^(NSString* uuid, NSString* architecture) {
    [uuids setObject:uuid forKey:architecture];
  }];

  XCTAssertEqual((NSUInteger)2, [uuids count], @"");
  XCTAssertEqualObjects([uuids objectForKey:@"armv7"], @"794523cb14ef3e6bb32a4ea39a7ac677", @"");
  XCTAssertEqualObjects([uuids objectForKey:@"armv7s"], @"0d1450b08b5e35b8bf1e442b7be4666b", @"");
}

@end
