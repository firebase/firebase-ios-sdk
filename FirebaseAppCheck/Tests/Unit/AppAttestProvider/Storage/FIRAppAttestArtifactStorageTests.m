/*
 * Copyright 2021 Google LLC
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

#import "FBLPromise+Testing.h"

#import "FirebaseAppCheck/Sources/AppAttestProvider/Storage/FIRAppAttestArtifactStorage.h"

@interface FIRAppAttestArtifactStorageTests : XCTestCase

@property(nonatomic) NSString *appName;
@property(nonatomic) NSString *appID;
@property(nonatomic) FIRAppAttestArtifactStorage *storage;

@end

@implementation FIRAppAttestArtifactStorageTests

- (void)setUp {
  [super setUp];

  self.appName = @"FIRAppAttestArtifactStorageTests";
  self.appID = @"1:100000000000:ios:aaaaaaaaaaaaaaaaaaaaaaaa";

  self.storage = [[FIRAppAttestArtifactStorage alloc] initWithAppName:self.appName
                                                                appID:self.appID
                                                          accessGroup:nil];
}

- (void)tearDown {
  self.storage = nil;
  [super tearDown];
}

- (void)testSetAndGetArtifact {
  [self assertSetGetForStorage];
}

- (void)testRemoveArtifact {
  // 1. Save an artifact to storage and check it is stored.
  [self assertSetGetForStorage];

  // 2. Remove artifact.
  __auto_type setPromise = [self.storage setArtifact:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(setPromise.value);
  XCTAssertNil(setPromise.error);

  // 3. Check it has been removed.
  __auto_type getPromise = [self.storage getArtifact];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertNil(getPromise.value);
  XCTAssertNil(getPromise.error);
}

- (void)testSetAndGetPerApp {
  // Assert storages for apps with the same name can independently set/get artifact.
  [self assertIndependentSetGetForStoragesWithAppName1:self.appName
                                                appID1:@"app_id"
                                              appName2:self.appName
                                                appID2:@"app_id_2"];
  // Assert storages for apps with the same app ID can independently set/get artifact.
  [self assertIndependentSetGetForStoragesWithAppName1:@"app_1"
                                                appID1:self.appID
                                              appName2:@"app_2"
                                                appID2:self.appID];
  // Assert storages for apps with different info can independently set/get artifact.
  [self assertIndependentSetGetForStoragesWithAppName1:@"app_1"
                                                appID1:@"app_id_1"
                                              appName2:@"app_2"
                                                appID2:@"app_id_2"];
}

#pragma mark - Helpers

- (void)assertSetGetForStorage {
  NSData *artifactToSet = [[NSUUID UUID].UUIDString dataUsingEncoding:NSUTF8StringEncoding];

  __auto_type setPromise = [self.storage setArtifact:artifactToSet];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise.value, artifactToSet);
  XCTAssertNil(setPromise.error);

  __auto_type getPromise = [self.storage getArtifact];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(getPromise.value, artifactToSet);
  XCTAssertNil(getPromise.error);
}

- (void)assertIndependentSetGetForStoragesWithAppName1:(NSString *)appName1
                                                appID1:(NSString *)appID1
                                              appName2:(NSString *)appName2
                                                appID2:(NSString *)appID2 {
  // Create two storages.
  FIRAppAttestArtifactStorage *storage1 =
      [[FIRAppAttestArtifactStorage alloc] initWithAppName:appName1 appID:appID1 accessGroup:nil];
  FIRAppAttestArtifactStorage *storage2 =
      [[FIRAppAttestArtifactStorage alloc] initWithAppName:appName2 appID:appID2 accessGroup:nil];
  // 1. Independently set artifacts for the two storages.
  NSData *artifact1 = [@"app_attest_artifact1" dataUsingEncoding:NSUTF8StringEncoding];
  FBLPromise *setPromise1 = [storage1 setArtifact:artifact1];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise1.value, artifact1);
  XCTAssertNil(setPromise1.error);

  NSData *artifact2 = [@"app_attest_artifact2" dataUsingEncoding:NSUTF8StringEncoding];
  __auto_type setPromise2 = [storage2 setArtifact:artifact2];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(setPromise2.value, artifact2);
  XCTAssertNil(setPromise2.error);

  // 2. Get artifacts for the two storages.
  __auto_type getPromise1 = [storage1 getArtifact];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(getPromise1.value, artifact1);
  XCTAssertNil(getPromise1.error);

  __auto_type getPromise2 = [storage2 getArtifact];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
  XCTAssertEqualObjects(getPromise2.value, artifact2);
  XCTAssertNil(getPromise2.error);

  // 3. Assert that artifacts were set and retrieved independently of one another.
  XCTAssertNotEqualObjects(getPromise1.value, getPromise2.value);

  // Cleanup storages.
  [storage1 setArtifact:nil];
  [storage2 setArtifact:nil];
  XCTAssert(FBLWaitForPromisesWithTimeout(0.5));
}

@end
