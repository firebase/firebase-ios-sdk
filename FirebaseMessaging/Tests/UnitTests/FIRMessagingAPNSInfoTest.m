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
#import <objc/runtime.h>

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
    kFIRMessagingTokenOptionsAPNSIsSandboxKey : @1234
  };
  NSError *error;
  FIRMessagingAPNSInfo *info =
      [[FIRMessagingAPNSInfo alloc] initWithTokenOptionsDictionary:validDictionary];
  NSData *archive = [NSKeyedArchiver archivedDataWithRootObject:info
                                          requiringSecureCoding:YES
                                                          error:&error];
  XCTAssertNil(error);
  NSSet *classes = [[NSSet alloc] initWithArray:@[ FIRMessagingAPNSInfo.class, NSData.class ]];
  FIRMessagingAPNSInfo *restoredInfo = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                           fromData:archive
                                                                              error:&error];
  XCTAssertNil(error);
  XCTAssertEqualObjects(info.deviceToken, restoredInfo.deviceToken);
  XCTAssertEqual(info.sandbox, restoredInfo.sandbox);
}

@interface FIRMessagingAPNSInfo_MutableDataFixture : FIRMessagingAPNSInfo
@end

@implementation FIRMessagingAPNSInfo_MutableDataFixture
- (void)encodeWithCoder:(NSCoder *)aCoder {
  NSMutableData *mutableToken =
      [NSMutableData dataWithData:[@"mutableTokenData" dataUsingEncoding:NSUTF8StringEncoding]];
  [aCoder encodeObject:mutableToken forKey:@"device_token"];
  [aCoder encodeBool:YES forKey:@"sandbox"];
}
@end

// Test that archiving a FIRMessagingAPNSInfo object holding an NSMutableData token
// and restoring it from the archive succeeds under secure coding.
- (void)testAPNSInfoEncodingAndDecodingWithMutableData {
  FIRMessagingAPNSInfo_MutableDataFixture *fixture =
      [[FIRMessagingAPNSInfo_MutableDataFixture alloc] init];
  NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initRequiringSecureCoding:YES];
  [archiver setClassName:@"FIRMessagingAPNSInfo"
                forClass:[FIRMessagingAPNSInfo_MutableDataFixture class]];
  [archiver encodeObject:fixture forKey:NSKeyedArchiveRootObjectKey];
  [archiver finishEncoding];
  NSData *archive = archiver.encodedData;
  XCTAssertNil(archiver.error);

  // Sanity check that the fixture archive actually encoded an NSMutableData instance.
  NSString *archiveString = [[NSString alloc] initWithData:archive
                                                  encoding:NSISOLatin1StringEncoding];
  XCTAssertTrue([archiveString containsString:@"NSMutableData"],
                @"Fixture archive must contain an encoded NSMutableData instance.");

  NSSet *classes = [[NSSet alloc]
      initWithArray:@[ FIRMessagingAPNSInfo.class, NSData.class, NSMutableData.class ]];
  NSError *error = nil;
  FIRMessagingAPNSInfo *restoredInfo = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes
                                                                           fromData:archive
                                                                              error:&error];
  XCTAssertNil(error);
  XCTAssertNotNil(restoredInfo);
  XCTAssertEqualObjects([@"mutableTokenData" dataUsingEncoding:NSUTF8StringEncoding],
                        restoredInfo.deviceToken);
  XCTAssertEqual(YES, restoredInfo.sandbox);
}

@end
