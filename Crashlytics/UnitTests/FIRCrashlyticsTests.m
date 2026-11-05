// Copyright 2026 Google LLC
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

#import <XCTest/XCTest.h>

#if __has_include(<FBLPromises/FBLPromises.h>)
#import <FBLPromises/FBLPromises.h>
#else
#import "FBLPromises.h"
#endif

#import "Crashlytics/Crashlytics/Public/FirebaseCrashlytics/FIRCrashlytics.h"

@interface FIRCrashlytics (UnitTests)

@property(nonatomic, nullable) FBLPromise<NSNumber *> *contextInitPromise;

- (void)waitForContextInit:(NSString *)contextLog callback:(void (^)(void))callback;

@end

@interface FIRCrashlyticsTests : XCTestCase
@end

@implementation FIRCrashlyticsTests

- (void)testFailedContextInitializationDoesNotRunCallback {
  FIRCrashlytics *crashlytics = [FIRCrashlytics alloc];
  crashlytics.contextInitPromise = [FBLPromise resolvedWith:@NO];
  XCTestExpectation *callback =
      [[XCTestExpectation alloc] initWithDescription:@"setup dependent callback"];
  callback.inverted = YES;

  [crashlytics waitForContextInit:@"test"
                         callback:^{
                           [callback fulfill];
                         }];

  [self waitForExpectations:@[ callback ] timeout:0.1];
}

- (void)testSuccessfulContextInitializationRunsCallbackOnce {
  FIRCrashlytics *crashlytics = [FIRCrashlytics alloc];
  FBLPromise<NSNumber *> *startup = [FBLPromise pendingPromise];
  crashlytics.contextInitPromise = startup;
  XCTestExpectation *callback =
      [[XCTestExpectation alloc] initWithDescription:@"setup dependent callback"];
  callback.assertForOverFulfill = YES;
  __block NSUInteger callbackCount = 0;

  [crashlytics waitForContextInit:@"test"
                         callback:^{
                           callbackCount++;
                           [callback fulfill];
                         }];
  [startup fulfill:@YES];
  [startup fulfill:@YES];

  [self waitForExpectations:@[ callback ] timeout:1.0];
  XCTAssertEqual(callbackCount, 1);
}

@end
