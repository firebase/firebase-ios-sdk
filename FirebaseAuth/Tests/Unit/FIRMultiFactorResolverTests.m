/*
 * Copyright 2022 Google LLC
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

#if TARGET_OS_IOS

#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorResolver+Internal.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAuth.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorInfo.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorResolver.h"
#import "FirebaseAuth/Tests/Unit/FIRApp+FIRAuthUnitTests.h"

/** @class FIRMultiFactorResolverTests
    @brief Tests for @c FIRMultiFactorResolver.
 */
@interface FIRMultiFactorResolverTests : XCTestCase

@end

@implementation FIRMultiFactorResolverTests

/** @fn testMultifactorResolverCreation
    @brief Tests succuessful creation of a @c FIRMultiFactorResolver object.
 */
- (void)testMultifactorResolverCreation {
  NSString *fakeMFAPendingCredential = @"fakeMFAPendingCredential";
  NSArray<FIRMultiFactorInfo *> *fakeHints = @[];

  FIRApp *app = [FIRApp appForAuthUnitTestsWithName:@"app"];
  FIRAuth *auth = [FIRAuth authWithApp:app];
  auth.tenantID = @"tenant-id";

  FIRMultiFactorResolver *resolver =
      [[FIRMultiFactorResolver alloc] initWithMFAPendingCredential:fakeMFAPendingCredential
                                                             hints:fakeHints
                                                              auth:auth];

  XCTAssertEqualObjects(resolver.auth, auth);
  XCTAssertEqualObjects(resolver.hints, fakeHints);
}

@end

#endif
