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

#include "Crashlytics/Crashlytics/Helpers/FIRCLSUtility.h"

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#include "Crashlytics/Shared/FIRCLSByteUtility.h"

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

- (void)testRedactUUID {
  // Define a local struct to hold the test data
  struct TestCase {
    const char *name;      // Name of the test case
    const char *readonly;  // Input string
    const char *expected;  // Expected output string
  };

  // Initialize an array of test cases
  struct TestCase tests[] = {
      {.name = "Test with valid UUID",
       .readonly = "CoreSimulator 704.12.1 - Device: iPhone SE (2nd generation) "
                   "(45D62CC2-CFB5-4E33-AB61-B0684627F1B6) - Runtime: iOS 13.4 (17E8260) - "
                   "DeviceType: iPhone SE (2nd generation)",
       .expected = "CoreSimulator 704.12.1 - Device: iPhone SE (2nd generation) "
                   "(********-****-****-****-************) - Runtime: iOS 13.4 (17E8260) - "
                   "DeviceType: iPhone SE (2nd generation)"},
      {.name = "Test with no UUID",
       .readonly = "Example with no UUID",
       .expected = "Example with no UUID"},
      {.name = "Test with only UUID",
       .readonly = "(12345678-1234-1234-1234-123456789012)",
       .expected = "(********-****-****-****-************)"},
      {.name = "Test with malformed UUID pattern",
       .readonly = "CoreSimulator 704.12.1 - Device: iPhone SE (2nd generation) "
                   "(45D62CC2-CFB5-4E33-AB61-B0684627F1B6",
       .expected = "CoreSimulator 704.12.1 - Device: iPhone SE (2nd generation) "
                   "(45D62CC2-CFB5-4E33-AB61-B0684627F1B6"},
      {.name = "Test with other error string",
       .readonly = "Fatal error: file "
                   "/Users/test/src/foo/bar/ViewController.swift, line 25",
       .expected = "Fatal error: file "
                   "/Users/test/src/foo/bar/ViewController.swift, line 25"},
      {.name = "Test with NULL input", .readonly = NULL, .expected = NULL}};

  // Loop over the array of test cases
  for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
    if (tests[i].readonly == NULL) {
      XCTAssertNoThrow(FIRCLSRedactUUID(NULL));
      continue;
    }

    // copy the message because the function modifies the input
    // and the input is const
    char message[256];
    snprintf(message, sizeof(message), "%s", tests[i].readonly);

    // Redact the UUID
    FIRCLSRedactUUID(message);

    // Compare the result with the expected output
    NSString *actual = [NSString stringWithUTF8String:message];
    NSString *expected = [NSString stringWithUTF8String:tests[i].expected];
    XCTAssertEqualObjects(actual, expected, @"Test named: '%s' failed", tests[i].name);
  }
}
@end
