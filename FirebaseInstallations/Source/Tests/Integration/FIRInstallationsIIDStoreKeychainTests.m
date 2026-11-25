/*
 * Copyright 2026 Google LLC
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

// Tests of the legacy Instance ID migration against the real keychain. They need keychain
// entitlements, so they run in the host app of `TestApp/FirebaseInstallationsTestApp.xcodeproj`.

#import <TargetConditionals.h>
// The macOS keychain asks for a password, and the data protection keychain needs a signing team.
#if !TARGET_OS_OSX

#import <Security/Security.h>
#import <XCTest/XCTest.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "FirebaseInstallations/Source/Library/IIDMigration/FIRInstallationsIIDStore.h"

static NSString *const kPublicKeyTagPrefix = @"com.google.iid.keypair.public-";
static NSString *const kPrivateKeyTagPrefix = @"com.google.iid.keypair.private-";
/// The key `FirebaseInstanceID` used in its plist to record that an IID was created.
static NSString *const kIIDCreationTimePlistKey = @"|S|cre";

@interface FIRInstallationsIIDStore (KeychainTests)
- (NSDictionary *)keyQueryForKeyWithTagPrefix:(NSString *)tagPrefix;
- (NSString *)keychainKeyTagWithPrefix:(NSString *)prefix;
- (NSString *)plistPath;
@end

/// Uses unique keychain tags and a temporary plist, so the tests don't touch the app's real IID
/// data or each other's.
@interface FIRInstallationsTestIIDStore : FIRInstallationsIIDStore
@property(nonatomic, copy) NSString *identifier;
@end

@implementation FIRInstallationsTestIIDStore

- (NSString *)keychainKeyTagWithPrefix:(NSString *)prefix {
  return [prefix stringByAppendingString:self.identifier];
}

- (NSString *)plistPath {
  return [NSTemporaryDirectory() stringByAppendingPathComponent:self.identifier];
}

@end

@interface FIRInstallationsIIDStoreKeychainTests : XCTestCase
@property(nonatomic) FIRInstallationsTestIIDStore *store;
@property(nonatomic) NSDictionary *publicKeyQuery;
@property(nonatomic) NSDictionary *privateKeyQuery;
@end

@implementation FIRInstallationsIIDStoreKeychainTests

- (void)setUp {
  [super setUp];
  self.store = [[FIRInstallationsTestIIDStore alloc] init];
  self.store.identifier = NSUUID.UUID.UUIDString;
  self.publicKeyQuery = [self.store keyQueryForKeyWithTagPrefix:kPublicKeyTagPrefix];
  self.privateKeyQuery = [self.store keyQueryForKeyWithTagPrefix:kPrivateKeyTagPrefix];
}

- (void)tearDown {
  SecItemDelete((__bridge CFDictionaryRef)self.publicKeyQuery);
  SecItemDelete((__bridge CFDictionaryRef)self.privateKeyQuery);
  [[NSFileManager defaultManager] removeItemAtPath:[self.store plistPath] error:nil];
  [super tearDown];
}

- (void)testDeleteExistingIIDRemovesBothLegacyKeys {
  [self createLegacyKeyPair];
  XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)self.publicKeyQuery, NULL),
                 errSecSuccess);
  XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)self.privateKeyQuery, NULL),
                 errSecSuccess);

  FBLPromise<NSNull *> *promise = [self.store deleteExistingIID];
  [self waitForPromise:promise];
  XCTAssertTrue(promise.isFulfilled);
  XCTAssertNil(promise.error);

  XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)self.publicKeyQuery, NULL),
                 errSecItemNotFound);
  XCTAssertEqual(SecItemCopyMatching((__bridge CFDictionaryRef)self.privateKeyQuery, NULL),
                 errSecItemNotFound);
}

- (void)testExistingIIDIsReadFromLegacyKeyAndPlist {
  [self createLegacyKeyPair];
  NSURL *plistURL = [NSURL fileURLWithPath:[self.store plistPath]];
  NSError *writeError;
  XCTAssertTrue([@{kIIDCreationTimePlistKey : @"1234"} writeToURL:plistURL error:&writeError],
                @"%@", writeError);

  FBLPromise<NSString *> *IIDPromise = [self.store existingIID];
  [self waitForPromise:IIDPromise];
  XCTAssertNil(IIDPromise.error);
  // The IID is the URL-safe base64 encoding of 8 bytes of the public key's SHA1 hash.
  XCTAssertEqual(IIDPromise.value.length, 11);

  // After deletion, there's no IID to migrate.
  FBLPromise<NSNull *> *deletePromise = [self.store deleteExistingIID];
  [self waitForPromise:deletePromise];
  XCTAssertTrue(deletePromise.isFulfilled);
  FBLPromise<NSString *> *deletedIIDPromise = [self.store existingIID];
  [self waitForPromise:deletedIIDPromise];
  XCTAssertTrue(deletedIIDPromise.isRejected);
}

- (void)testExistingIIDWithoutPlistFlagIsNotFound {
  [self createLegacyKeyPair];

  FBLPromise<NSString *> *IIDPromise = [self.store existingIID];
  [self waitForPromise:IIDPromise];
  XCTAssertTrue(IIDPromise.isRejected);
}

#pragma mark - Helpers

/// Waits for `promise` to settle while the main run loop keeps running. Blocking the main thread
/// on the promise would wait on the store's utility queue at a higher QoS.
- (void)waitForPromise:(FBLPromise *)promise {
  XCTestExpectation *expectation = [self expectationWithDescription:@"promise settled"];
  promise.always(^{
    [expectation fulfill];
  });
  [self waitForExpectations:@[ expectation ] timeout:5];
}

/// Creates a permanent RSA key pair the way `FirebaseInstanceID` did.
- (void)createLegacyKeyPair {
  NSString *publicTag = [self.store keychainKeyTagWithPrefix:kPublicKeyTagPrefix];
  NSString *privateTag = [self.store keychainKeyTagWithPrefix:kPrivateKeyTagPrefix];
  NSDictionary *attributes = @{
    (__bridge id)kSecAttrKeyType : (__bridge id)kSecAttrKeyTypeRSA,
    (__bridge id)kSecAttrKeySizeInBits : @2048,
    (__bridge id)kSecPublicKeyAttrs : @{
      (__bridge id)kSecAttrIsPermanent : @YES,
      (__bridge id)kSecAttrApplicationTag : [publicTag dataUsingEncoding:NSUTF8StringEncoding]
    },
    (__bridge id)kSecPrivateKeyAttrs : @{
      (__bridge id)kSecAttrIsPermanent : @YES,
      (__bridge id)kSecAttrApplicationTag : [privateTag dataUsingEncoding:NSUTF8StringEncoding]
    }
  };
  SecKeyRef publicKey = NULL;
  SecKeyRef privateKey = NULL;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
  OSStatus status =
      SecKeyGeneratePair((__bridge CFDictionaryRef)attributes, &publicKey, &privateKey);
#pragma clang diagnostic pop
  if (publicKey) {
    CFRelease(publicKey);
  }
  if (privateKey) {
    CFRelease(privateKey);
  }
  XCTAssertEqual(status, errSecSuccess);
}

@end

#endif  // !TARGET_OS_OSX
