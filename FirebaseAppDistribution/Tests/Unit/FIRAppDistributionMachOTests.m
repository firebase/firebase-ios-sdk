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

#import <FirebaseCore/FIRAppInternal.h>
#import "FIRAppDistributionMachO+Private.h"

@interface FIRAppDistributionMachOTests : XCTestCase
@end

@implementation FIRAppDistributionMachOTests

- (NSString*)resourcePath:(NSString*)path {
  NSBundle* bundle = [NSBundle bundleForClass:[self class]];
  NSString* resourcePath = [bundle resourcePath];

  return [resourcePath stringByAppendingPathComponent:path];
}

- (void)testCodeHashForSingleArchIntelSimulator {
  FIRAppDistributionMachO* macho;
  macho = [[FIRAppDistributionMachO alloc] initWithPath:[self resourcePath:@"x86_64-executable"]];
  XCTAssertEqualObjects([macho codeHash], @"442eb836efe1f56bf8a65b2a0a78b2f8d3e792e7");
}

- (void)testCodeHashForMultipleArch {
  FIRAppDistributionMachO* macho;
  macho =
      [[FIRAppDistributionMachO alloc] initWithPath:[self resourcePath:@"armv7-armv7s-executable"]];
  XCTAssertEqualObjects([macho codeHash], @"80cc0ec0af8a0169831abcc73177eb2b57990bc0");
}

@end
