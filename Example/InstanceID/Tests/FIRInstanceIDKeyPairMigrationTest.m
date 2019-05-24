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

#import "Firebase/InstanceID/FIRInstanceIDBackupExcludedPlist.h"
#import "Firebase/InstanceID/FIRInstanceIDConstants.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPair.h"
#import "Firebase/InstanceID/FIRInstanceIDKeychain.h"

#import <OCMock/OCMock.h>
#import "Firebase/InstanceID/FIRInstanceIDKeyPair.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPairStore.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPairUtilities.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"

@interface FIRInstanceIDKeyPairStore (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRInstanceIDBackupExcludedPlist *plist;
@property(atomic, readwrite, strong) FIRInstanceIDKeyPair *keyPair;
BOOL FIRInstanceIDHasMigratedKeyPair(NSString *legacyPublicKeyTag, NSString *newPublicKeyTag);
NSString *FIRInstanceIDLegacyPublicTagWithSubtype(NSString *subtype);
NSString *FIRInstanceIDLegacyPrivateTagWithSubtype(NSString *subtype);
NSString *FIRInstanceIDPublicTagWithSubtype(NSString *subtype);
NSString *FIRInstanceIDPrivateTagWithSubtype(NSString *subtype);
+ (FIRInstanceIDKeyPair *)keyPairForPrivateKeyTag:(NSString *)privateKeyTag
                                     publicKeyTag:(NSString *)publicKeyTag
                                            error:(NSError *__autoreleasing *)error;
+ (void)deleteKeyPairWithPrivateTag:(NSString *)privateTag
                          publicTag:(NSString *)publicTag
                            handler:(void (^)(NSError *))handler;
- (void)migrateKeyPairCacheIfNeededWithHandler:(void (^)(NSError *error))handler;
+ (NSString *)keyStoreFileName;

- (void)updateKeyRef:(SecKeyRef)keyRef
             withTag:(NSString *)tag
             handler:(void (^)(NSError *error))handler;
@end

// Need to separate the tests from FIRInstanceIDKeyPairStoreTest for separate keychain operations
@interface FIRInstanceIDKeyPairMigrationTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRInstanceIDKeyPairStore *keyPairStore;

@end

@implementation FIRInstanceIDKeyPairMigrationTest

- (void)setUp {
  [super setUp];
  id mockStoreClass = OCMClassMock([FIRInstanceIDKeyPairStore class]);
  [[[mockStoreClass stub] andReturn:@"com.google.iid-keypairmanager-test"] keyStoreFileName];
  _keyPairStore = [[FIRInstanceIDKeyPairStore alloc] init];
}

- (void)tearDown {
  [super tearDown];
  NSError *error = nil;
  [self.keyPairStore removeKeyPairCreationTimePlistWithError:&error];
}

- (void)testMigrationDataIfLegacyKeyPairsNotExist {
  NSString *legacyPublicKeyTag =
      FIRInstanceIDLegacyPublicTagWithSubtype(kFIRInstanceIDKeyPairSubType);

  NSString *publicKeyTag = FIRInstanceIDPublicTagWithSubtype(kFIRInstanceIDKeyPairSubType);
  XCTAssertFalse(FIRInstanceIDHasMigratedKeyPair(legacyPublicKeyTag, publicKeyTag));

  NSString *legacyPrivateKeyTag =
      FIRInstanceIDLegacyPrivateTagWithSubtype(kFIRInstanceIDKeyPairSubType);
  NSError *error;
  FIRInstanceIDKeyPair *keyPair =
      [FIRInstanceIDKeyPairStore keyPairForPrivateKeyTag:legacyPrivateKeyTag
                                            publicKeyTag:legacyPublicKeyTag
                                                   error:&error];
  XCTAssertFalse([keyPair isValid]);
}

- (void)testMigrationIfLegacyKeyPairsExist {
  XCTestExpectation *migrationCompleteExpectation =
      [self expectationWithDescription:@"migration should be done"];
  // create legacy key pairs
  NSString *legacyPublicKeyTag =
      FIRInstanceIDLegacyPublicTagWithSubtype(kFIRInstanceIDKeyPairSubType);
  NSString *legacyPrivateKeyTag =
      FIRInstanceIDLegacyPrivateTagWithSubtype(kFIRInstanceIDKeyPairSubType);
  FIRInstanceIDKeyPair *keyPair =
      [[FIRInstanceIDKeychain sharedInstance] generateKeyPairWithPrivateTag:legacyPrivateKeyTag
                                                                  publicTag:legacyPublicKeyTag];
  XCTAssertTrue([keyPair isValid]);

  NSError *error;
  NSString *publicKeyTag = FIRInstanceIDPublicTagWithSubtype(kFIRInstanceIDKeyPairSubType);
  NSString *privateKeyTag = FIRInstanceIDPrivateTagWithSubtype(kFIRInstanceIDKeyPairSubType);

  XCTAssertFalse(FIRInstanceIDHasMigratedKeyPair(legacyPublicKeyTag, publicKeyTag));

  FIRInstanceIDKeyPair *keyPair1 =
      [FIRInstanceIDKeyPairStore keyPairForPrivateKeyTag:legacyPrivateKeyTag
                                            publicKeyTag:legacyPublicKeyTag
                                                   error:&error];
  XCTAssertTrue([keyPair1 isValid]);

  [self.keyPairStore migrateKeyPairCacheIfNeededWithHandler:^(NSError *error) {
    XCTAssertNil(error);
    XCTAssertTrue(FIRInstanceIDHasMigratedKeyPair(legacyPublicKeyTag, publicKeyTag));

    FIRInstanceIDKeyPair *keyPair2 =
        [FIRInstanceIDKeyPairStore keyPairForPrivateKeyTag:privateKeyTag
                                              publicKeyTag:publicKeyTag
                                                     error:&error];

    XCTAssertTrue([keyPair2 isValid]);
    XCTAssertEqualObjects(keyPair.publicKeyData, keyPair2.publicKeyData);
    XCTAssertEqualObjects(keyPair.privateKeyData, keyPair2.privateKeyData);

    // Clear the legacy data after tests
    [FIRInstanceIDKeyPairStore deleteKeyPairWithPrivateTag:legacyPrivateKeyTag
                                                 publicTag:legacyPublicKeyTag
                                                   handler:^(NSError *error) {
                                                     XCTAssertNil(error);
                                                     [migrationCompleteExpectation fulfill];
                                                   }];
  }];

  [self waitForExpectationsWithTimeout:1 handler:nil];
}

// Disabling test for now. We need to find a flake free way to insure the publicKeyRef is retained.
#ifdef DISABLED
- (void)testUpdateKeyRefWithTagRetainsAndReleasesKeyRef {
  __weak id publicKeyRef;

  @autoreleasepool {
    NSString *legacyPublicKeyTag =
        FIRInstanceIDLegacyPublicTagWithSubtype(kFIRInstanceIDKeyPairSubType);
    NSString *legacyPrivateKeyTag =
        FIRInstanceIDLegacyPrivateTagWithSubtype(kFIRInstanceIDKeyPairSubType);
    FIRInstanceIDKeyPair *keyPair =
        [[FIRInstanceIDKeychain sharedInstance] generateKeyPairWithPrivateTag:legacyPrivateKeyTag
                                                                    publicTag:legacyPublicKeyTag];
    XCTAssertTrue([keyPair isValid]);

    publicKeyRef = (__bridge id)keyPair.publicKey;

    XCTestExpectation *completionExpectation =
        [self expectationWithDescription:@"completionExpectation"];
    [self.keyPairStore updateKeyRef:keyPair.publicKey
                            withTag:@"test"
                            handler:^(NSError *error) {
                              [completionExpectation fulfill];
                            }];
  }

  // Should be still alive until execution finished
  XCTAssertNotNil(publicKeyRef);

  [self waitForExpectationsWithTimeout:0.5 handler:NULL];

  // Should be released once finished
  XCTAssertNil(publicKeyRef);
}

@end
