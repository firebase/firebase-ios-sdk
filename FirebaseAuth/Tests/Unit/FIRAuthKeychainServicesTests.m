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

#import <Security/Security.h>
#import <XCTest/XCTest.h>

#import "FirebaseAuth/Sources/Storage/FIRAuthKeychainServices.h"

/** @var kAccountPrefix
    @brief The keychain account prefix assumed by the tests.
 */
static NSString *const kAccountPrefix = @"firebase_auth_1_";

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

/** @fn accountFromKey
    @brief Converts a key string to an account string.
    @param key The key string to be converted from.
    @return The account string being the conversion result.
 */
static NSString *accountFromKey(NSString *key) {
  return [kAccountPrefix stringByAppendingString:key];
}

/** @fn dataFromString
    @brief Converts a NSString to NSData.
    @param string The NSString to be converted from.
    @return The NSData being the conversion result.
 */
static NSData *dataFromString(NSString *string) {
  return [string dataUsingEncoding:NSUTF8StringEncoding];
}

/** @fn stringFromData
    @brief Converts a NSData to NSString.
    @param data The NSData to be converted from.
    @return The NSString being the conversion result.
 */
static NSString *stringFromData(NSData *data) {
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

/** @fn fakeError
    @brief Creates a fake error object.
    @return a non-nil NSError instance.
 */
static NSError *fakeError() {
  return [NSError errorWithDomain:@"ERROR" code:-1 userInfo:nil];
}

@interface FIRAuthKeychainServices ()

// Exposed for testing.
- (nullable NSData *)itemWithQuery:(NSDictionary *)query error:(NSError **_Nullable)error;

@end

/** @class FIRAuthKeychainTests
    @brief Tests for @c FIRAuthKeychainTests .
 */
@interface FIRAuthKeychainTests : XCTestCase
@end

@implementation FIRAuthKeychainTests

/** @fn testReadNonexisting
    @brief Tests reading non-existing keychain item.
 */
- (void)testReadNonexisting {
  [self setPassword:nil account:accountFromKey(kKey) service:kService];
  [self setPassword:nil account:kKey service:nil];  // legacy form
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  NSError *error = fakeError();
  XCTAssertNil([keychain dataForKey:kKey error:&error]);
  XCTAssertNil(error);
}

/** @fn testReadExisting
    @brief Tests reading existing keychain item.
 */
- (void)testReadExisting {
  [self setPassword:kData account:accountFromKey(kKey) service:kService];
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  NSError *error = fakeError();
  XCTAssertEqualObjects([keychain dataForKey:kKey error:&error], dataFromString(kData));
  XCTAssertNil(error);
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kService];
}

/** @fn testReadMultiple
    @brief Tests reading multiple items from keychain returns only the first item.
 */
- (void)testReadMultiple {
  [self addPassword:kData account:accountFromKey(kKey) service:kService];
  [self addPassword:kOtherData account:accountFromKey(kKey) service:kOtherService];
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  NSString *queriedAccount = accountFromKey(kKey);
  NSDictionary *query = @{
    (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrAccount : queriedAccount,
  };
  NSError *error = fakeError();
  // Keychain on macOS returns items in a different order than keychain on iOS,
  // so test that the returned object is one of any of the added objects.
  NSData *queriedData = [keychain itemWithQuery:query error:&error];
  BOOL isValidKeychainItem =
      [@[ dataFromString(kData), dataFromString(kOtherData) ] containsObject:queriedData];
  XCTAssertTrue(isValidKeychainItem);
  XCTAssertNil(error);
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kService];
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kOtherService];
}

/** @fn testNotReadOtherService
    @brief Tests not reading keychain item belonging to other service.
 */
- (void)testNotReadOtherService {
  [self setPassword:nil account:accountFromKey(kKey) service:kService];
  [self setPassword:kData account:accountFromKey(kKey) service:kOtherService];
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  NSError *error = fakeError();
  XCTAssertNil([keychain dataForKey:kKey error:&error]);
  XCTAssertNil(error);
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kOtherService];
}

/** @fn testWriteNonexisting
    @brief Tests writing new keychain item.
 */
- (void)testWriteNonexisting {
  [self setPassword:nil account:accountFromKey(kKey) service:kService];
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  XCTAssertTrue([keychain setData:dataFromString(kData) forKey:kKey error:NULL]);
  XCTAssertEqualObjects([self passwordWithAccount:accountFromKey(kKey) service:kService], kData);
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kService];
}

/** @fn testWriteExisting
    @brief Tests overwriting existing keychain item.
 */
- (void)testWriteExisting {
  [self setPassword:kData account:accountFromKey(kKey) service:kService];
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  XCTAssertTrue([keychain setData:dataFromString(kOtherData) forKey:kKey error:NULL]);
  XCTAssertEqualObjects([self passwordWithAccount:accountFromKey(kKey) service:kService],
                        kOtherData);
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kService];
}

/** @fn testDeleteNonexisting
    @brief Tests deleting non-existing keychain item.
 */
- (void)testDeleteNonexisting {
  [self setPassword:nil account:accountFromKey(kKey) service:kService];
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  XCTAssertTrue([keychain removeDataForKey:kKey error:NULL]);
  XCTAssertNil([self passwordWithAccount:accountFromKey(kKey) service:kService]);
}

/** @fn testDeleteExisting
    @brief Tests deleting existing keychain item.
 */
- (void)testDeleteExisting {
  [self setPassword:kData account:accountFromKey(kKey) service:kService];
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  XCTAssertTrue([keychain removeDataForKey:kKey error:NULL]);
  XCTAssertNil([self passwordWithAccount:accountFromKey(kKey) service:kService]);
}

/** @fn testReadLegacy
    @brief Tests reading legacy keychain item.
 */
- (void)testReadLegacy {
  [self setPassword:nil account:accountFromKey(kKey) service:kService];
  [self setPassword:kData account:kKey service:nil];  // legacy form
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  NSError *error = fakeError();
  XCTAssertEqualObjects([keychain dataForKey:kKey error:&error], dataFromString(kData));
  XCTAssertNil(error);
  // Legacy item should have been moved to current form.
  XCTAssertEqualObjects([self passwordWithAccount:accountFromKey(kKey) service:kService], kData);
  XCTAssertNil([self passwordWithAccount:kKey service:nil]);
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kService];
}

/** @fn testNotReadLegacy
    @brief Tests not reading legacy keychain item because current keychain item exists.
 */
- (void)testNotReadLegacy {
  [self setPassword:kData account:accountFromKey(kKey) service:kService];
  [self setPassword:kOtherData account:kKey service:nil];  // legacy form
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  NSError *error = fakeError();
  XCTAssertEqualObjects([keychain dataForKey:kKey error:&error], dataFromString(kData));
  XCTAssertNil(error);
  // Legacy item should have leave untouched.
  XCTAssertEqualObjects([self passwordWithAccount:accountFromKey(kKey) service:kService], kData);
  XCTAssertEqualObjects([self passwordWithAccount:kKey service:nil], kOtherData);
  [self deletePasswordWithAccount:accountFromKey(kKey) service:kService];
  [self deletePasswordWithAccount:kKey service:nil];
}

/** @fn testRemoveLegacy
    @brief Tests removing keychain item also removes legacy keychain item.
 */
- (void)testRemoveLegacy {
  [self setPassword:kData account:accountFromKey(kKey) service:kService];
  [self setPassword:kOtherData account:kKey service:nil];  // legacy form
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  XCTAssertTrue([keychain removeDataForKey:kKey error:NULL]);
  XCTAssertNil([self passwordWithAccount:accountFromKey(kKey) service:kService]);
  XCTAssertNil([self passwordWithAccount:kKey service:nil]);
}

/** @fn testNullErrorParameter
    @brief Tests that 'NULL' can be safely passed in.
 */
- (void)testNullErrorParameter {
  FIRAuthKeychainServices *keychain = [[FIRAuthKeychainServices alloc] initWithService:kService];
  [keychain dataForKey:kKey error:NULL];
  [keychain setData:dataFromString(kData) forKey:kKey error:NULL];
  [keychain removeDataForKey:kKey error:NULL];
}

#pragma mark - Helpers

/** @fn passwordWithAccount:service:
    @brief Reads a generic password string from the keychain.
    @param account The account attribute of the keychain item.
    @param service The service attribute of the keychain item, if provided.
    @return The generic password string, if the keychain item exists.
 */
- (nullable NSString *)passwordWithAccount:(nonnull NSString *)account
                                   service:(nullable NSString *)service {
  NSMutableDictionary *query = [@{
    (__bridge id)kSecReturnData : @YES,
    (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrAccount : account,
  } mutableCopy];
  if (service) {
    query[(__bridge id)kSecAttrService] = service;
  }
  CFDataRef result;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
  if (status == errSecItemNotFound) {
    return nil;
  }
  XCTAssertEqual(status, errSecSuccess);
  return stringFromData((__bridge NSData *)(result));
}

/** @fn addPassword:account:service:
    @brief Adds a generic password string to the keychain.
    @param password The value attribute for the password to write to the keychain item.
    @param account The account attribute of the keychain item.
    @param service The service attribute of the keychain item, if provided.
 */
- (void)addPassword:(nonnull NSString *)password
            account:(nonnull NSString *)account
            service:(nullable NSString *)service {
  NSMutableDictionary *query = [@{
    (__bridge id)kSecValueData : dataFromString(password),
    (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrAccount : account,
  } mutableCopy];
  if (service) {
    query[(__bridge id)kSecAttrService] = service;
  }
  OSStatus status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
  XCTAssertEqual(status, errSecSuccess);
}

/** @fn deletePasswordWithAccount:service:
    @brief Deletes a generic password string from the keychain.
    @param account The account attribute of the keychain item.
    @param service The service attribute of the keychain item, if provided.
 */
- (void)deletePasswordWithAccount:(nonnull NSString *)account service:(nullable NSString *)service {
  NSMutableDictionary *query = [@{
    (__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrAccount : account,
  } mutableCopy];
  if (service) {
    query[(__bridge id)kSecAttrService] = service;
  }
  OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
  XCTAssertEqual(status, errSecSuccess);
}

/** @fn setPasswordWithString:account:service:
    @brief Sets a generic password string to the keychain.
    @param password The value attribute of the keychain item, if provided, or nil to delete the
        existing password if any.
    @param account The account attribute of the keychain item.
    @param service The service attribute of the keychain item, if provided.
 */
- (void)setPassword:(nullable NSString *)password
            account:(nonnull NSString *)account
            service:(nullable NSString *)service {
  if ([self passwordWithAccount:account service:service]) {
    [self deletePasswordWithAccount:account service:service];
  }
  if (password) {
    [self addPassword:password account:account service:service];
  }
}

@end
