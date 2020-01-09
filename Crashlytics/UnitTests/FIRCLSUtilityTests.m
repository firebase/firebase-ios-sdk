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

#include "FIRCLSUtility.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "FIRCLSByteUtility.h"

@interface FIRCLSUtilityTests : XCTestCase

@end

@implementation FIRCLSUtilityTests

- (void)setUp {
  [super setUp];
  // Put setup code here. This method is called before the invocation of each test method in the
  // class.
}

- (void)tearDown {
  // Put teardown code here. This method is called after the invocation of each test method in the
  // class.
  [super tearDown];
}

- (void)testHexFromByte {
  char output[2] = {0, 0};

  FIRCLSHexFromByte('A', output);

  XCTAssertEqual(output[0], '4', @"");
  XCTAssertEqual(output[1], '1', @"");
}

- (void)testHexFromByteForNotPrintableCharacter {
  char output[2] = {0, 0};

  FIRCLSHexFromByte(0xd0, output);

  XCTAssertEqual(output[0], 'd', @"");
  XCTAssertEqual(output[1], '0', @"");
}

- (void)testHexToString {
  const uint8_t bytes[8] = {'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'};

  char string[(sizeof(bytes) * 2) + 1];

  FIRCLSSafeHexToString(bytes, 8, string);

  string[(sizeof(bytes) * 2)] = 0;

  XCTAssertEqualObjects([NSString stringWithUTF8String:string], @"6162636465666768", @"");
}

- (void)testHexToStringWithNonPrintableCharacters {
  const uint8_t bytes[4] = {0x52, 0xd0, 0x4e, 0x1f};

  char string[(sizeof(bytes) * 2) + 1];

  FIRCLSSafeHexToString(bytes, 4, string);

  XCTAssertEqualObjects([NSString stringWithUTF8String:string], @"52d04e1f", @"");
}

@end
