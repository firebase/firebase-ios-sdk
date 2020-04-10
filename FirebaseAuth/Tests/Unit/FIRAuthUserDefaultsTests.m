/*
 * Copyright 2017 Google
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

#import "FirebaseAuth/Sources/Storage/FIRAuthUserDefaults.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kKey
    @brief The key used in tests.
 */
static NSString *const kKey = @"ACCOUNT";

/** @var kService
    @brief The keychain service used in tests.
 */
static NSString *const kService = @"SERVICE";

/** @var kOtherService
    @brief Another keychain service used in tests.
 */
static NSString *const kOtherService = @"OTHER_SERVICE";

/** @var kData
    @brief A piece of keychain data used in tests.
 */
static NSString *const kData = @"DATA";

/** @var kOtherData
    @brief Another piece of keychain data used in tests.
 */
static NSString *const kOtherData = @"OTHER_DATA";

/** @fn dataFromString
    @brief Converts a NSString to NSData.
    @param string The NSString to be converted from.
    @return The NSData being the conversion result.
 */
static NSData *dataFromString(NSString *string) {
  return [string dataUsingEncoding:NSUTF8StringEncoding];
}

/** @fn fakeError
    @brief Creates a fake error object.
    @return a non-nil NSError instance.
 */
static NSError *fakeError() {
  return [NSError errorWithDomain:@"ERROR" code:-1 userInfo:nil];
}

/** @class FIRAuthUserDefaultsTests
    @brief Tests for @c FIRAuthUserDefaults.
 */
@interface FIRAuthUserDefaultsTests : XCTestCase
@end

@implementation FIRAuthUserDefaultsTests {
  /** @var _storage
      @brief The @c FIRAuthUserDefaults object under test.
   */
  FIRAuthUserDefaults *_storage;
}

- (void)setUp {
  [super setUp];
  _storage = [[FIRAuthUserDefaults alloc] initWithService:kService];
  [_storage clear];
}

/** @fn testReadNonexisting
    @brief Tests reading non-existing storage item.
 */
- (void)testReadNonExisting {
  NSError *error = fakeError();
  XCTAssertNil([_storage dataForKey:kKey error:&error]);
  XCTAssertNil(error);
}

/** @fn testWriteRead
    @brief Tests writing and reading a storage item.
 */
- (void)testWriteRead {
  XCTAssertTrue([_storage setData:dataFromString(kData) forKey:kKey error:NULL]);
  NSError *error = fakeError();
  XCTAssertEqualObjects([_storage dataForKey:kKey error:&error], dataFromString(kData));
  XCTAssertNil(error);
}

/** @fn testOverwrite
    @brief Tests overwriting a storage item.
 */
- (void)testOverwrite {
  XCTAssertTrue([_storage setData:dataFromString(kData) forKey:kKey error:NULL]);
  XCTAssertTrue([_storage setData:dataFromString(kOtherData) forKey:kKey error:NULL]);
  NSError *error = fakeError();
  XCTAssertEqualObjects([_storage dataForKey:kKey error:&error], dataFromString(kOtherData));
  XCTAssertNil(error);
}

/** @fn testRemove
    @brief Tests removing a storage item.
 */
- (void)testRemove {
  XCTAssertTrue([_storage setData:dataFromString(kData) forKey:kKey error:NULL]);
  XCTAssertTrue([_storage removeDataForKey:kKey error:NULL]);
  NSError *error = fakeError();
  XCTAssertNil([_storage dataForKey:kKey error:&error]);
  XCTAssertNil(error);
}

/** @fn testServices
    @brief Tests storage items belonging to different services doesn't affect each other.
 */
- (void)testServices {
  XCTAssertTrue([_storage setData:dataFromString(kData) forKey:kKey error:NULL]);
  _storage = [[FIRAuthUserDefaults alloc] initWithService:kOtherService];
  NSError *error = fakeError();
  XCTAssertNil([_storage dataForKey:kKey error:&error]);
  XCTAssertNil(error);
}

/** @fn testStandardUserDefaults
    @brief Tests standard user defaults are not affected by FIRAuthUserDefaults operations,
 */
- (void)testStandardUserDefaults {
  NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
  NSUInteger count =
      [userDefaults persistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]].count;
  XCTAssertTrue([_storage setData:dataFromString(kData) forKey:kKey error:NULL]);
  XCTAssertNil([userDefaults dataForKey:kKey]);
  XCTAssertEqual(
      [userDefaults persistentDomainForName:[[NSBundle mainBundle] bundleIdentifier]].count, count);
}

@end

NS_ASSUME_NONNULL_END
