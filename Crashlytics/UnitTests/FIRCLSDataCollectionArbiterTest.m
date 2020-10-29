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

#import "Crashlytics/Crashlytics/DataCollection/FIRCLSDataCollectionArbiter.h"

#import <XCTest/XCTest.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "Crashlytics/Crashlytics/FIRCLSUserDefaults/FIRCLSUserDefaults.h"
#import "Crashlytics/UnitTests/Mocks/FIRAppFake.h"

#pragma mark - Tests for FIRCLSDataCollectionArbiter

@interface FIRCLSDataCollectionArbiterTest : XCTestCase
@property(nonatomic, readwrite) FIRAppFake *fakeApp;
@end

@implementation FIRCLSDataCollectionArbiterTest

- (void)setUp {
  [super setUp];

  self.fakeApp = [[FIRAppFake alloc] init];

  [[FIRCLSUserDefaults standardUserDefaults] removeAllObjects];
  [[FIRCLSUserDefaults standardUserDefaults] synchronize];
}

- (void)tearDown {
  [[FIRCLSUserDefaults standardUserDefaults] removeAllObjects];
  [[FIRCLSUserDefaults standardUserDefaults] synchronize];

  [super tearDown];
}

- (void)testNothingSet {
  self.fakeApp.isDefaultCollectionEnabled = YES;
  FIRCLSDataCollectionArbiter *arbiter = [self arbiterWithDictionary:@{}];
#ifdef CRASHLYTICS_1P
  XCTAssertFalse([arbiter isCrashlyticsCollectionEnabled]);
#else
  // It should be YES by default for 3P users.
  XCTAssertTrue([arbiter isCrashlyticsCollectionEnabled]);
#endif
}

- (void)testOnlyStickyOff {
  FIRCLSDataCollectionArbiter *arbiter = [self arbiterWithDictionary:@{}];
  [arbiter setCrashlyticsCollectionEnabled:NO];
  XCTAssertFalse([arbiter isCrashlyticsCollectionEnabled]);
}

- (void)testOnlyFlagOff {
  FIRCLSDataCollectionArbiter *arbiter =
      [self arbiterWithDictionary:[self fabricConfigWithDataCollectionValue:NO]];
  XCTAssertFalse([arbiter isCrashlyticsCollectionEnabled]);
}

- (void)testOnlyFIRAppOff {
  self.fakeApp.isDefaultCollectionEnabled = NO;
  FIRCLSDataCollectionArbiter *arbiter = [self arbiterWithDictionary:@{}];
  XCTAssertFalse([arbiter isCrashlyticsCollectionEnabled]);
}

- (void)testStickyPrecedent {
  FIRCLSDataCollectionArbiter *arbiter =
      [self arbiterWithDictionary:[self fabricConfigWithDataCollectionValue:NO]];
  self.fakeApp.isDefaultCollectionEnabled = NO;
  [arbiter setCrashlyticsCollectionEnabled:YES];
  XCTAssertTrue([arbiter isCrashlyticsCollectionEnabled]);
  XCTAssertFalse([arbiter isLegacyDataCollectionKeyInPlist]);
}

- (void)testPlistPrecedent {
  FIRCLSDataCollectionArbiter *arbiter =
      [self arbiterWithDictionary:[self fabricConfigWithDataCollectionValue:YES]];
  self.fakeApp.isDefaultCollectionEnabled = NO;
  XCTAssertTrue([arbiter isCrashlyticsCollectionEnabled]);
  XCTAssertFalse([arbiter isLegacyDataCollectionKeyInPlist]);
}

- (void)testLegacyFlag {
  FIRCLSDataCollectionArbiter *arbiter =
      [self arbiterWithDictionary:[self fabricConfigWithLegacyDataCollectionValue:YES]];
  XCTAssertTrue([arbiter isLegacyDataCollectionKeyInPlist]);
}

- (void)testLegacyAndNewImplementationsAreIndependent {
  FIRCLSDataCollectionArbiter *arbiter =
      [self arbiterWithDictionary:[self fabricConfigWithLegacyDataCollectionValue:YES]];
  self.fakeApp.isDefaultCollectionEnabled = NO;
  XCTAssertFalse([arbiter isCrashlyticsCollectionEnabled]);
  XCTAssertTrue([arbiter isLegacyDataCollectionKeyInPlist]);
}

- (void)testLegacyAndNewFlagsAreIndependent {
  FIRCLSDataCollectionArbiter *arbiter =
      [self arbiterWithDictionary:[self fabricConfigWithDataCollectionValue:YES andLegacy:NO]];
  self.fakeApp.isDefaultCollectionEnabled = YES;
  XCTAssertTrue([arbiter isCrashlyticsCollectionEnabled]);
  XCTAssertTrue([arbiter isLegacyDataCollectionKeyInPlist]);
}

- (XCTestExpectation *)expectationForPromise:(FBLPromise *)promise {
  XCTestExpectation *expectation = [[XCTestExpectation alloc] initWithDescription:@"promise"];
  [promise then:^id _Nullable(id _Nullable value) {
    [expectation fulfill];
    return nil;
  }];
  return expectation;
}

- (void)testWaitForCrashlyticsCollectionEnabled {
  // true, wait
  FIRCLSDataCollectionArbiter *arbiter = [self arbiterWithDictionary:@{}];
  [arbiter setCrashlyticsCollectionEnabled:YES];
  FBLPromise *promise = [arbiter waitForCrashlyticsCollectionEnabled];
  [self waitForExpectations:@[ [self expectationForPromise:promise] ] timeout:1.0];

  // false, wait, true
  [arbiter setCrashlyticsCollectionEnabled:NO];
  promise = [arbiter waitForCrashlyticsCollectionEnabled];
  [arbiter setCrashlyticsCollectionEnabled:YES];
  [self waitForExpectations:@[ [self expectationForPromise:promise] ] timeout:1.0];

  // false, wait, false, true
  [arbiter setCrashlyticsCollectionEnabled:NO];
  promise = [arbiter waitForCrashlyticsCollectionEnabled];
  [arbiter setCrashlyticsCollectionEnabled:NO];
  [arbiter setCrashlyticsCollectionEnabled:YES];
  [self waitForExpectations:@[ [self expectationForPromise:promise] ] timeout:1.0];
}

#pragma mark - Helper functions

- (FIRCLSDataCollectionArbiter *)arbiterWithDictionary:(NSDictionary *)dict {
  id fakeApp = self.fakeApp;
  return [[FIRCLSDataCollectionArbiter alloc] initWithApp:fakeApp withAppInfo:dict];
}

- (NSDictionary *)fabricConfigWithDataCollectionValue:(BOOL)enabled {
  return @{@"FirebaseCrashlyticsCollectionEnabled" : @(enabled)};
}

- (NSDictionary *)fabricConfigWithLegacyDataCollectionValue:(BOOL)enabled {
  return @{@"firebase_crashlytics_collection_enabled" : @(enabled)};
}

- (NSDictionary *)fabricConfigWithDataCollectionValue:(BOOL)enabled andLegacy:(BOOL)legacyEnabled {
  return @{
    @"FirebaseCrashlyticsCollectionEnabled" : @(enabled),
    @"firebase_crashlytics_collection_enabled" : @(legacyEnabled)
  };
}

@end
