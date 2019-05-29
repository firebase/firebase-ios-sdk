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
#import "Firebase/InstanceID/FIRInstanceIDStore.h"

#import <OCMock/OCMock.h>
#import "Firebase/InstanceID/FIRInstanceIDKeyPair.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPairStore.h"
#import "Firebase/InstanceID/FIRInstanceIDKeyPairUtilities.h"
#import "Firebase/InstanceID/FIRInstanceIDUtilities.h"

@interface FIRInstanceIDKeyPairStore (ExposedForTest)

@property(nonatomic, readwrite, strong) FIRInstanceIDBackupExcludedPlist *plist;
@property(nonatomic, readwrite, strong) FIRInstanceIDKeyPair *keyPair;
+ (NSString *)appIDKeyWithSubtype:(NSString *)subtype;
+ (NSString *)creationTimeKeyWithSubtype:(NSString *)subtype;
- (FIRInstanceIDKeyPair *)generateAndSaveKeyWithSubtype:(NSString *)subtype
                                           creationTime:(int64_t)creationTime
                                                  error:(NSError **)error;
- (FIRInstanceIDKeyPair *)validCachedKeyPairWithSubtype:(NSString *)subtype error:(NSError **)error;
+ (NSString *)keyStoreFileName;
- (void)migrateKeyPairCacheIfNeededWithHandler:(void (^)(NSError *error))handler;
@end

@interface FIRInstanceIDKeyPairStoreTest : XCTestCase

@property(nonatomic, readwrite, strong) FIRInstanceIDKeyPairStore *keyPairStore;

@end

@implementation FIRInstanceIDKeyPairStoreTest

- (void)setUp {
  [super setUp];
  id mockStoreClass = OCMClassMock([FIRInstanceIDKeyPairStore class]);
  [[[mockStoreClass stub] andReturn:@"com.google.iid-keypairmanager-test"] keyStoreFileName];
  // Should make sure the standard directory is created.
  if (![FIRInstanceIDStore hasSubDirectory:kFIRInstanceIDSubDirectoryName]) {
    [FIRInstanceIDStore createSubDirectory:kFIRInstanceIDSubDirectoryName];
  }
  _keyPairStore = [[FIRInstanceIDKeyPairStore alloc] init];
}

- (void)tearDown {
  NSError *error = nil;
  [self.keyPairStore removeKeyPairCreationTimePlistWithError:&error];

  XCTestExpectation *queueDrained = [self expectationWithDescription:@"drainKeychainQueue"];
  [self.keyPairStore deleteSavedKeyPairWithSubtype:kFIRInstanceIDKeyPairSubType
                                           handler:^(NSError *error) {
                                             [queueDrained fulfill];
                                           }];
  [self waitForExpectations:@[ queueDrained ] timeout:10];

  [super tearDown];
}

/**
 *  The app identity generated should be 11 chars and start with k, l, m, n. It should
 *  not have "=" as suffix since we do not allow wrapping.
 */
- (void)testIdentity {
  NSError *error;
  FIRInstanceIDKeyPair *keyPair = [self.keyPairStore loadKeyPairWithError:&error];
  NSString *iid = FIRInstanceIDAppIdentity(keyPair);
  XCTAssertEqual(11, iid.length);
  XCTAssertFalse([iid hasSuffix:@"="]);
}

/**
 *  All identities should be cleared if the associated keypair plist file is missing.
 *  This indicates that the app is either a fresh install, or was removed and reinstalled.
 *
 *  If/when iOS changes the behavior of the Keychain to also invalidate items when an app is
 *  installed, this check will no longer be required (both the plist file and the keychain items
 *  would be missing).
 */
- (void)testIdentityIsInvalidatedWithMissingPlist {
  // Mock that the plist doesn't exist, and call the invalidation check. It should
  // trigger the identities to be deleted.
  id plistMock = OCMPartialMock(self.keyPairStore.plist);
  [[[plistMock stub] andReturnValue:[NSNumber numberWithBool:NO]] doesFileExist];
  // Mock the keypair store, to check if key pair deletes are requested
  id storeMock = OCMPartialMock(self.keyPairStore);
  // Now trigger a possible invalidation.
  [self.keyPairStore invalidateKeyPairsIfNeeded];
  // Verify that delete was called
  OCMVerify([storeMock deleteSavedKeyPairWithSubtype:[OCMArg any] handler:[OCMArg any]]);
}

- (void)testMigrationWhenPlistExist {
  // Mock that the plist doesn't exist, and call the invalidation check. It should
  // trigger the identities to be deleted.
  id plistMock = OCMPartialMock(self.keyPairStore.plist);
  [[[plistMock stub] andReturnValue:[NSNumber numberWithBool:YES]] doesFileExist];
  // Mock the keypair store, to check if key pair deletes are requested
  id storeMock = OCMPartialMock(self.keyPairStore);
  // Now trigger a possible invalidation.
  [self.keyPairStore invalidateKeyPairsIfNeeded];
  // Verify that delete was called
  OCMVerify([storeMock migrateKeyPairCacheIfNeededWithHandler:nil]);
}

/**
 *  The app identity should change when deleted and regenerated.
 */
- (void)testResetIdentity {
  XCTestExpectation *identityResetExpectation =
      [self expectationWithDescription:@"Identity should be reset"];
  NSError *error;
  FIRInstanceIDKeyPair *keyPair = [self.keyPairStore loadKeyPairWithError:&error];
  XCTAssertNil(error);
  NSString *iid1 = FIRInstanceIDAppIdentity(keyPair);

  [self.keyPairStore deleteSavedKeyPairWithSubtype:kFIRInstanceIDKeyPairSubType
                                           handler:^(NSError *error) {
                                             XCTAssertNil(error);
                                             [identityResetExpectation fulfill];
                                           }];

  [self waitForExpectationsWithTimeout:5 handler:nil];

  [self.keyPairStore removeKeyPairCreationTimePlistWithError:&error];
  XCTAssertNil(error);

  // regenerate instance-id
  FIRInstanceIDKeyPair *keyPair2 = [self.keyPairStore loadKeyPairWithError:&error];
  XCTAssertNil(error);
  NSString *iid2 = FIRInstanceIDAppIdentity(keyPair2);

  XCTAssertNotEqualObjects(iid1, iid2);
}

/**
 *  We should always cache a valid keypair.
 */
- (void)testCachedKeyPair {
  NSError *error;
  FIRInstanceIDKeyPair *keyPair = [self.keyPairStore loadKeyPairWithError:&error];
  XCTAssertNil(error);
  NSString *iid1 = FIRInstanceIDAppIdentity(keyPair);

  // sleep for some time
  [NSThread sleepForTimeInterval:2.0];

  keyPair = [self.keyPairStore loadKeyPairWithError:&error];
  XCTAssertNil(error);
  NSString *iid2 = FIRInstanceIDAppIdentity(keyPair);

  XCTAssertTrue([self.keyPairStore hasCachedKeyPairs]);
  XCTAssertEqualObjects(iid1, iid2);
}

- (void)testAppIdentity {
  NSError *error;
  NSString *iid1 = [self.keyPairStore appIdentityWithError:&error];
  // sleep for some time
  [NSThread sleepForTimeInterval:2.0];

  NSString *iid2 = [self.keyPairStore appIdentityWithError:&error];

  XCTAssertEqualObjects(iid1, iid2);
}

/**
 *  Test KeyPair cache. After generating a new keyPair requesting it from the cache
 *  should be successfull and return the same keyPair.
 */
- (void)testKeyPairCache {
  // TODO: figure out why same query doesn't work for macOS.
#if TARGET_OS_IOS || TARGET_OS_TV
  NSError *error;

  FIRInstanceIDKeyPair *keyPair1 =
      [self.keyPairStore generateAndSaveKeyWithSubtype:kFIRInstanceIDKeyPairSubType
                                          creationTime:FIRInstanceIDCurrentTimestampInSeconds()
                                                 error:&error];
  XCTAssertNotNil(keyPair1);
  NSString *iid1 = FIRInstanceIDAppIdentity(keyPair1);

  [NSThread sleepForTimeInterval:2.0];

  FIRInstanceIDKeyPair *keyPair2 =
      [self.keyPairStore validCachedKeyPairWithSubtype:kFIRInstanceIDKeyPairSubType error:&error];
  XCTAssertNil(error);
  NSString *iid2 = FIRInstanceIDAppIdentity(keyPair2);

  XCTAssertEqualObjects(iid1, iid2);
#endif
}
/**
 *  Test that if the Keychain preferences does not store any KeyPair, trying to
 *  load one from the cache should return nil.
 */
- (void)testInvalidKeyPair {
  NSError *error;
  FIRInstanceIDKeyPair *keyPair =
      [self.keyPairStore validCachedKeyPairWithSubtype:kFIRInstanceIDKeyPairSubType error:&error];
  XCTAssertFalse([keyPair isValid]);
}

/**
 *  Test deleting the keyPair from Keychain preferences.
 */
- (void)testDeleteKeyPair {
  XCTestExpectation *deleteKeyPairExpectation =
      [self expectationWithDescription:@"Keypair should be deleted"];
  NSError *error;
  [self.keyPairStore generateAndSaveKeyWithSubtype:kFIRInstanceIDKeyPairSubType
                                      creationTime:FIRInstanceIDCurrentTimestampInSeconds()
                                             error:&error];

  XCTAssertNil(error);

  [self.keyPairStore
      deleteSavedKeyPairWithSubtype:kFIRInstanceIDKeyPairSubType
                            handler:^(NSError *error) {
                              XCTAssertNil(error);
                              FIRInstanceIDKeyPair *keyPair2 = [self.keyPairStore
                                  validCachedKeyPairWithSubtype:kFIRInstanceIDKeyPairSubType
                                                          error:&error];
                              XCTAssertNotNil(error);
                              XCTAssertNil(keyPair2);
                              [deleteKeyPairExpectation fulfill];
                            }];
  [self waitForExpectationsWithTimeout:1 handler:nil];
}

@end
