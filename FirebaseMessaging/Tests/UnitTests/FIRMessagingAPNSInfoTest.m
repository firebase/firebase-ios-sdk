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

#import <XCTest/XCTest.h>

#import <GoogleUtilities/GULSecureCoding.h>
#import "FirebaseMessaging/Sources/FIRMessagingConstants.h"
#import "FirebaseMessaging/Sources/Token/FIRMessagingAPNSInfo.h"

@interface FIRMessagingAPNSInfoTest : XCTestCase

@end

@implementation FIRMessagingAPNSInfoTest

- (void)testAPNSInfoCreationWithValidDictionary {
  NSDictionary *validDictionary = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"tokenData" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @(YES)
  };
  FIRMessagingAPNSInfo *info =
      [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  XCTAssertNotNil(info);
  XCTAssertEqualObjects(info.deviceToken, validDictionary[kFIRMessagingTokenOptionsAPNSKey]);
  XCTAssertEqual(info.sandbox,
                 [validDictionary[kFIRMessagingTokenOptionsAPNSIsSandboxKey] boolValue]);
}

- (void)testAPNSInfoCreationWithInvalidDictionary {
  NSDictionary *validDictionary = @{};
  FIRMessagingAPNSInfo *info =
      [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  XCTAssertNil(info);
}

- (void)testAPNSInfoCreationWithInvalidTokenFormat {
  // Token data stored as NSString instead of NSData
  NSDictionary *badDictionary = @{
    kFIRMessagingTokenOptionsAPNSKey : @"tokenDataAsString",
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @(YES)
  };
  FIRMessagingAPNSInfo *info =
      [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:badDictionary];
  XCTAssertNil(info);
}

- (void)testAPNSInfoCreationWithInvalidSandboxFormat {
  // Sandbox key stored as NSString instead of NSNumber (bool)
  NSDictionary *validDictionary = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"tokenData" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @"sandboxValueAsString"
  };
  FIRMessagingAPNSInfo *info =
      [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  XCTAssertNil(info);
}

// Test that archiving a FIRMessagingAPNSInfo object and restoring it from the archive
// yields the same values for all the fields.
- (void)testAPNSInfoEncodingAndDecoding {
  NSDictionary *validDictionary = @{
    kFIRMessagingTokenOptionsAPNSKey : [@"tokenData" dataUsingEncoding:NSUTF8StringEncoding],
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @"sandboxValueAsString"
  };
  FIRMessagingAPNSInfo *info =
      [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  NSError *error;
  NSData *archive = [GULSecureCoding archivedDataWithRootObject:info error:&error];
  NSError *unarchiveError;
  FIRMessagingAPNSInfo *restoredInfo = [GULSecureCoding
      unarchivedObjectOfClasses:[NSSet setWithObjects:FIRMessagingAPNSInfo.class, nil]
                       fromData:archive
                          error:&unarchiveError];
  XCTAssertEqualObjects(info.deviceToken, restoredInfo.deviceToken);
  XCTAssertEqual(info.sandbox, restoredInfo.sandbox);
}

@end
