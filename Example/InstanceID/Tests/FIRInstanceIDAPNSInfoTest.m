/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "Firebase/InstanceID/FIRInstanceIDAPNSInfo.h"

#import <XCTest/XCTest.h>

#import "Firebase/InstanceID/FIRInstanceIDConstants.h"

@interface FIRInstanceIDAPNSInfoTest : XCTestCase

@end

@implementation FIRInstanceIDAPNSInfoTest

- (void)testAPNSInfoCreationWithValidDictionary {
  NSDictionary *validDictionary = @{
    kFIRInstanceIDTokenOptionsAPNSKey : [@"tokenData" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(YES)
  };
  FIRInstanceIDAPNSInfo *info =
      [[FIRInstanceIDAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  XCTAssertNotNil(info);
  XCTAssertEqualObjects(info.deviceToken, validDictionary[kFIRInstanceIDTokenOptionsAPNSKey]);
  XCTAssertEqual(info.sandbox,
                 [validDictionary[kFIRInstanceIDTokenOptionsAPNSIsSandboxKey] boolValue]);
}

- (void)testAPNSInfoCreationWithInvalidDictionary {
  NSDictionary *validDictionary = @{};
  FIRInstanceIDAPNSInfo *info =
      [[FIRInstanceIDAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  XCTAssertNil(info);
}

- (void)testAPNSInfoCreationWithInvalidTokenFormat {
  // Token data stored as NSString instead of NSData
  NSDictionary *badDictionary = @{
    kFIRInstanceIDTokenOptionsAPNSKey : @"tokenDataAsString",
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @(YES)
  };
  FIRInstanceIDAPNSInfo *info =
      [[FIRInstanceIDAPNSInfo alloc] initWithTokenOptionsDictionary:badDictionary];
  XCTAssertNil(info);
}

- (void)testAPNSInfoCreationWithInvalidSandboxFormat {
  // Sandbox key stored as NSString instead of NSNumber (bool)
  NSDictionary *validDictionary = @{
    kFIRInstanceIDTokenOptionsAPNSKey : [@"tokenData" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @"sandboxValueAsString"
  };
  FIRInstanceIDAPNSInfo *info =
      [[FIRInstanceIDAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  XCTAssertNil(info);
}

// Test that archiving a FIRInstanceIDAPNSInfo object and restoring it from the archive
// yields the same values for all the fields.
- (void)testAPNSInfoEncodingAndDecoding {
  NSDictionary *validDictionary = @{
    kFIRInstanceIDTokenOptionsAPNSKey : [@"tokenData" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRInstanceIDTokenOptionsAPNSIsSandboxKey : @"sandboxValueAsString"
  };
  FIRInstanceIDAPNSInfo *info =
      [[FIRInstanceIDAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:info];
  FIRInstanceIDAPNSInfo *restoredInfo = [NSKeyedUnarchiver unarchiveObjectWithData:archive];
#pragma clang diagnostic pop
  XCTAssertEqualObjects(info.deviceToken, restoredInfo.deviceToken);
  XCTAssertEqual(info.sandbox, restoredInfo.sandbox);
}

@end
