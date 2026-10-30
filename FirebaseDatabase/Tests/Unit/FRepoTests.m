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

#import <XCTest/XCTest.h>

#import "FirebaseCore/Extension/FirebaseCoreInternal.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRDatabaseQuery_Private.h"
#import "FirebaseDatabase/Sources/Constants/FConstants.h"
#import "FirebaseDatabase/Sources/Core/FPersistentConnection.h"
#import "FirebaseDatabase/Sources/Core/FRepoInfo.h"
#import "FirebaseDatabase/Sources/Core/FRepoManager.h"
#import "FirebaseDatabase/Sources/Core/FRepo_Private.h"
#import "FirebaseDatabase/Tests/Helpers/FTestHelpers.h"

/** A connection that fails every get with the configured status and reason. */
@interface FFailingGetConnection : FPersistentConnection

@property(nonatomic, copy) NSString *status;
@property(nonatomic, strong) id reason;

@end

@implementation FFailingGetConnection

- (void)getDataAtPath:(NSString *)pathString
           withParams:(NSDictionary *)queryWireProtocolParams
         withCallback:(fbt_void_nsstring_id_nsstring)onComplete {
  onComplete(self.status, nil, self.reason);
}

@end

@interface FRepoTests : XCTestCase

@property(nonatomic, strong) FIRDatabaseConfig *config;
@property(nonatomic, strong) FRepo *repo;
@property(nonatomic, strong) FFailingGetConnection *connection;

@end

@implementation FRepoTests

- (void)setUp {
  [super setUp];
  self.config = [FTestHelpers configForName:@"FRepoTests"];
  FRepoInfo *repoInfo = [[FRepoInfo alloc] initWithHost:@"example.com"
                                               isSecure:NO
                                          withNamespace:@"default"];
  self.repo = [FRepoManager getRepo:repoInfo config:self.config];
  self.connection = [[FFailingGetConnection alloc] initWithRepoInfo:repoInfo
                                                      dispatchQueue:[FIRDatabaseQuery sharedQueue]
                                                             config:self.config];
  // Replace the repo's connection once the repo has finished initializing on the shared queue, so
  // that the repo never reaches the network.
  dispatch_sync([FIRDatabaseQuery sharedQueue], ^{
    [self.repo.connection interruptForReason:kFInterruptReasonRepoInterrupt];
    self.repo.connection = self.connection;
  });
}

- (void)tearDown {
  [FRepoManager disposeRepos:self.config];
  [super tearDown];
}

- (void)testGetDataFailureReportsReason {
  NSError *error = [self getDataErrorWithStatus:@"permission_denied" reason:@"Permission denied"];
  XCTAssertEqualObjects(error.localizedFailureReason, @"Permission denied");
}

- (void)testGetDataFailureWithoutReasonReportsStatus {
  NSError *error = [self getDataErrorWithStatus:@"permission_denied" reason:nil];
  XCTAssertEqualObjects(error.localizedFailureReason, @"permission_denied");
}

- (void)testGetDataFailureWithNonStringReasonReportsStatus {
  NSError *error = [self getDataErrorWithStatus:@"permission_denied" reason:@{@"code" : @403}];
  XCTAssertEqualObjects(error.localizedFailureReason, @"permission_denied");
}

- (void)testGetDataFailureWithoutStatusOrReasonReportsFailure {
  NSError *error = [self getDataErrorWithStatus:nil reason:nil];
  XCTAssertEqualObjects(error.localizedFailureReason, kFWPResponseForActionStatusFailed);
}

/** Calls getData on the repo while its connection fails gets with `status` and `reason`. */
- (NSError *)getDataErrorWithStatus:(NSString *)status reason:(id)reason {
  self.connection.status = status;
  self.connection.reason = reason;
  FIRDatabaseReference *ref = [[FIRDatabaseReference alloc] initWithRepo:self.repo
                                                                    path:PATH(@"foo")];
  XCTestExpectation *completed = [self expectationWithDescription:@"getData completed"];
  __block NSError *getDataError = nil;
  [ref getDataWithCompletionBlock:^(NSError *error, FIRDataSnapshot *snapshot) {
    XCTAssertNil(snapshot);
    getDataError = error;
    [completed fulfill];
  }];
  [self waitForExpectations:@[ completed ] timeout:5];

  XCTAssertEqualObjects(getDataError.domain, kFirebaseCoreErrorDomain);
  XCTAssertEqual(getDataError.code, 1);
  return getDataError;
}

@end
