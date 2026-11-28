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

@interface FIRCLSUtilityMutableDescriptionObject : NSObject <NSCopying>

@property(nonatomic, strong, nullable) NSMutableString *backingDescription;
@property(nonatomic, assign) NSUInteger descriptionCallCount;

- (instancetype)initWithDescription:(nullable NSString *)description;

@end

@implementation FIRCLSUtilityMutableDescriptionObject

- (instancetype)initWithDescription:(nullable NSString *)description {
  self = [super init];
  if (self) {
    _backingDescription = [description mutableCopy];
  }
  return self;
}

- (id)copyWithZone:(nullable NSZone *)zone {
  return self;
}

- (NSString *)description {
  self.descriptionCallCount += 1;
  return (NSString *)self.backingDescription;
}

@end

@interface FIRCLSUtilityNoDescriptionObject : NSObject <NSCopying>
@end

@implementation FIRCLSUtilityNoDescriptionObject

- (id)copyWithZone:(nullable NSZone *)zone {
  return self;
}

- (BOOL)respondsToSelector:(SEL)aSelector {
  if (aSelector == @selector(description)) {
    return NO;
  }
  return [super respondsToSelector:aSelector];
}

@end

@interface FIRCLSUtilityUnsafeEqualObject : NSObject <NSCopying>

@property(nonatomic, copy, readonly) NSString *token;
@property(nonatomic, assign) NSUInteger isEqualCallCount;

- (instancetype)initWithToken:(NSString *)token;

@end

@implementation FIRCLSUtilityUnsafeEqualObject

- (instancetype)initWithToken:(NSString *)token {
  self = [super init];
  if (self) {
    _token = [token copy];
  }
  return self;
}

- (id)copyWithZone:(nullable NSZone *)zone {
  return self;
}

- (BOOL)isEqual:(id)object {
  self.isEqualCallCount += 1;
  // Intentionally assumes `object` is the same class without checking `isKindOfClass:`.
  return [self.token isEqualToString:[(FIRCLSUtilityUnsafeEqualObject *)object token]];
}

- (NSUInteger)hash {
  return self.token.hash;
}

- (NSString *)description {
  return self.token;
}

@end

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

- (void)testReadStringWithTerminatorInRange {
  char buffer[64];
  memset(buffer, 'a', sizeof(buffer));
  buffer[31] = 0;

  char *string = NULL;

  XCTAssertTrue(FIRCLSReadString((vm_address_t)buffer, &string, 32));
  XCTAssertEqual(string, (char *)buffer);
  if (string != NULL) {
    XCTAssertEqual(strlen(string), (size_t)31);
  }
}

- (void)testReadStringWithoutTerminatorInRange {
  char buffer[64];
  memset(buffer, 'a', sizeof(buffer));
  // The terminator sits one byte past the window FIRCLSReadString is allowed
  // to read, so it must not count.
  buffer[32] = 0;

  char *string = NULL;

  XCTAssertFalse(FIRCLSReadString((vm_address_t)buffer, &string, 32));
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

- (void)testCopyValueWithNilAndNSNull {
  XCTAssertNil(FIRCLSCopyValue(nil));
  XCTAssertEqual(FIRCLSCopyValue([NSNull null]), [NSNull null]);
}

- (void)testCopyValueSnapshotsMutableAndTaggedStrings {
  NSMutableString *mutableString = [@"initial-string" mutableCopy];
  NSString *copied = FIRCLSCopyValue(mutableString);
  [mutableString setString:@"mutated-string"];

  XCTAssertEqualObjects(copied, @"initial-string");
  XCTAssertNotEqual(copied, mutableString);
  XCTAssertThrows([(NSMutableString *)copied appendString:@"!"]);
  XCTAssertEqualObjects(FIRCLSCopyValue(@""), @"");
  XCTAssertEqualObjects(FIRCLSCopyValue(@"a"), @"a");
}

- (void)testCopyValueConvertsNumbersBooleansAndCustomObjects {
  XCTAssertEqualObjects(FIRCLSCopyValue(@0), @"0");
  XCTAssertEqualObjects(FIRCLSCopyValue(@42), @"42");
  XCTAssertEqualObjects(FIRCLSCopyValue(@(-3.5)), @"-3.5");
  XCTAssertEqualObjects(FIRCLSCopyValue(@YES), @"1");
  XCTAssertEqualObjects(FIRCLSCopyValue(@NO), @"0");

  FIRCLSUtilityMutableDescriptionObject *mutableDescObj =
      [[FIRCLSUtilityMutableDescriptionObject alloc] initWithDescription:@"initial-desc"];
  NSString *copiedDesc = FIRCLSCopyValue(mutableDescObj);
  [mutableDescObj.backingDescription setString:@"mutated-desc"];

  XCTAssertEqual(mutableDescObj.descriptionCallCount, 1);
  XCTAssertEqualObjects(copiedDesc, @"initial-desc");
  XCTAssertNotEqual(copiedDesc, mutableDescObj.backingDescription);
  XCTAssertThrows([(NSMutableString *)copiedDesc appendString:@"!"]);

  FIRCLSUtilityMutableDescriptionObject *nilDescObj =
      [[FIRCLSUtilityMutableDescriptionObject alloc] initWithDescription:nil];
  XCTAssertNil(FIRCLSCopyValue(nilDescObj));
  XCTAssertEqual(nilDescObj.descriptionCallCount, 1);

  FIRCLSUtilityNoDescriptionObject *noDescObj = [[FIRCLSUtilityNoDescriptionObject alloc] init];
  XCTAssertNil(FIRCLSCopyValue(noDescObj));
}

- (void)testCopyDictionaryWithNilAndEmptyDictionaries {
  XCTAssertNil(FIRCLSCopyDictionary(nil, NO));
  XCTAssertNil(FIRCLSCopyDictionary(nil, YES));
  XCTAssertEqualObjects(FIRCLSCopyDictionary(@{}, NO), @{});
  XCTAssertEqualObjects(FIRCLSCopyDictionary(@{}, YES), @{});

  NSMutableDictionary *emptyMutable = [NSMutableDictionary dictionary];
  NSDictionary *copiedEmpty = FIRCLSCopyDictionary(emptyMutable, NO);
  emptyMutable[@"later"] = @"value";

  XCTAssertEqualObjects(copiedEmpty, @{});
  XCTAssertFalse([copiedEmpty isKindOfClass:[NSMutableDictionary class]]);
}

- (void)testCopyDictionarySnapshotsMutableEntriesPreservesNSNullValuesAndSkipsInvalidEntries {
  NSMutableString *mutableKey = [@"mut-key" mutableCopy];
  NSMutableString *mutableVal = [@"mut-val" mutableCopy];
  FIRCLSUtilityMutableDescriptionObject *customVal =
      [[FIRCLSUtilityMutableDescriptionObject alloc] initWithDescription:@"obj-desc"];
  FIRCLSUtilityMutableDescriptionObject *nilDescKey =
      [[FIRCLSUtilityMutableDescriptionObject alloc] initWithDescription:nil];
  FIRCLSUtilityMutableDescriptionObject *nilDescVal =
      [[FIRCLSUtilityMutableDescriptionObject alloc] initWithDescription:nil];
  FIRCLSUtilityNoDescriptionObject *noDescKey = [[FIRCLSUtilityNoDescriptionObject alloc] init];
  FIRCLSUtilityNoDescriptionObject *noDescVal = [[FIRCLSUtilityNoDescriptionObject alloc] init];

  NSMutableDictionary *source = [NSMutableDictionary dictionary];
  source[mutableKey] = mutableVal;
  source[@99] = customVal;
  source[@"clear-key"] = [NSNull null];
  source[[NSNull null]] = @"should-skip-null-key";
  source[nilDescKey] = @"should-skip-nil-desc-key";
  source[@"nil-desc-val"] = nilDescVal;
  source[noDescKey] = @"should-skip-no-desc-key";
  source[@"no-desc-val"] = noDescVal;

  NSDictionary *copiedSkippingNil = FIRCLSCopyDictionary(source, NO);
  NSDictionary *copiedMappingNilToNSNull = FIRCLSCopyDictionary(source, YES);

  // Mutate source keys, values, and entries after copying.
  [mutableKey setString:@"changed-key"];
  [mutableVal setString:@"changed-val"];
  [customVal.backingDescription setString:@"changed-desc"];
  source[@"added-after"] = @"extra";

  XCTAssertFalse([copiedSkippingNil isKindOfClass:[NSMutableDictionary class]]);
  XCTAssertFalse([copiedMappingNilToNSNull isKindOfClass:[NSMutableDictionary class]]);
  XCTAssertEqual(customVal.descriptionCallCount, 2);

  NSDictionary *expectedSkippingNil = @{
    @"mut-key" : @"mut-val",
    @"99" : @"obj-desc",
    @"clear-key" : [NSNull null],
  };
  XCTAssertEqualObjects(copiedSkippingNil, expectedSkippingNil);

  NSDictionary *expectedMappingNilToNSNull = @{
    @"mut-key" : @"mut-val",
    @"99" : @"obj-desc",
    @"clear-key" : [NSNull null],
    @"nil-desc-val" : [NSNull null],
    @"no-desc-val" : [NSNull null],
  };
  XCTAssertEqualObjects(copiedMappingNilToNSNull, expectedMappingNilToNSNull);
}

- (void)testCopyValueAndDictionaryDoNotInvokeIsEqualAgainstNSNull {
  FIRCLSUtilityUnsafeEqualObject *unsafeKey =
      [[FIRCLSUtilityUnsafeEqualObject alloc] initWithToken:@"unsafe-key"];
  FIRCLSUtilityUnsafeEqualObject *unsafeVal =
      [[FIRCLSUtilityUnsafeEqualObject alloc] initWithToken:@"unsafe-val"];

  XCTAssertNoThrow(FIRCLSCopyValue(unsafeVal));
  XCTAssertEqualObjects(FIRCLSCopyValue(unsafeVal), @"unsafe-val");
  XCTAssertEqual(unsafeVal.isEqualCallCount, 0);

  NSDictionary *copied = nil;
  XCTAssertNoThrow(copied = FIRCLSCopyDictionary(@{unsafeKey : unsafeVal}, NO));
  XCTAssertEqualObjects(copied, @{@"unsafe-key" : @"unsafe-val"});
  XCTAssertEqual(unsafeKey.isEqualCallCount, 0);
  XCTAssertEqual(unsafeVal.isEqualCallCount, 0);
}

@end
