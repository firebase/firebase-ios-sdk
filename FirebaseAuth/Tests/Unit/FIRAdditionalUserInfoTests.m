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
#import "OCMock.h"

#import "FirebaseAuth/Sources/Backend/RPC/FIRVerifyAssertionResponse.h"
#import "FirebaseAuth/Sources/User/FIRAdditionalUserInfo_Internal.h"

NS_ASSUME_NONNULL_BEGIN

/** @var kUserName
    @brief The fake user name.
 */
static NSString *const kUserName = @"User Doe";

/** @var kIsNewUser
    @brief The fake flag that indicates the user has signed in for the first time.
 */
static BOOL kIsNewUser = YES;

/** @var kProviderID
    @brief The fake Provider ID.
 */
static NSString *const kProviderID = @"PROVIDER_ID";

/** @class FIRAdditionalUserInfoTests
    @brief Tests for @c FIRAdditionalUserInfo .
 */
@interface FIRAdditionalUserInfoTests : XCTestCase
@end

@implementation FIRAdditionalUserInfoTests

/** @fn googleProfile
    @brief The fake user profile under additional user data in @c FIRVerifyAssertionResponse.
 */
+ (NSDictionary *)profile {
  static NSDictionary *kProfile = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    kProfile = @{@"email" : @"user@mail.com", @"given_name" : @"User", @"family_name" : @"Doe"};
  });
  return kProfile;
}

/** @fn testAditionalUserInfoCreation
    @brief Tests succuessful creation of @c FIRAdditionalUserInfo with
        @c initWithProviderID:profile:username: call.
 */
- (void)testAditionalUserInfoCreation {
  FIRAdditionalUserInfo *userInfo =
      [[FIRAdditionalUserInfo alloc] initWithProviderID:kProviderID
                                                profile:[[self class] profile]
                                               username:kUserName
                                              isNewUser:kIsNewUser];
  XCTAssertEqualObjects(userInfo.providerID, kProviderID);
  XCTAssertEqualObjects(userInfo.profile, [[self class] profile]);
  XCTAssertEqualObjects(userInfo.username, kUserName);
  XCTAssertEqual(userInfo.isNewUser, kIsNewUser);
}

/** @fn testAditionalUserInfoCreationWithStaticInitializer
    @brief Tests succuessful creation of @c FIRAdditionalUserInfo with
        @c userInfoWithVerifyAssertionResponse call.
 */
- (void)testAditionalUserInfoCreationWithStaticInitializer {
  id mockVeriyAssertionResponse = OCMClassMock([FIRVerifyAssertionResponse class]);
  OCMExpect([mockVeriyAssertionResponse providerID]).andReturn(kProviderID);
  OCMExpect([mockVeriyAssertionResponse profile]).andReturn([[self class] profile]);
  OCMExpect([mockVeriyAssertionResponse username]).andReturn(kUserName);
  OCMExpect([mockVeriyAssertionResponse isNewUser]).andReturn(kIsNewUser);

  FIRAdditionalUserInfo *userInfo =
      [FIRAdditionalUserInfo userInfoWithVerifyAssertionResponse:mockVeriyAssertionResponse];
  XCTAssertEqualObjects(userInfo.providerID, kProviderID);
  XCTAssertEqualObjects(userInfo.profile, [[self class] profile]);
  XCTAssertEqualObjects(userInfo.username, kUserName);
  XCTAssertEqual(userInfo.isNewUser, kIsNewUser);
  OCMVerifyAll(mockVeriyAssertionResponse);
}

/** @fn testAdditionalUserInfoCoding
    @brief Tests successful archiving and unarchiving of @c FIRAdditionalUserInfo.
 */
- (void)testAdditionalUserInfoCoding {
  FIRAdditionalUserInfo *userInfo =
      [[FIRAdditionalUserInfo alloc] initWithProviderID:kProviderID
                                                profile:[[self class] profile]
                                               username:kUserName
                                              isNewUser:kIsNewUser];
  NSData *data = [NSKeyedArchiver archivedDataWithRootObject:userInfo];
  XCTAssertNotNil(data, @"Should not be nil if archiving succeeded.");
  XCTAssertNoThrow([NSKeyedUnarchiver unarchiveObjectWithData:data],
                   @"Unarchiving should not throw and exception.");
  FIRAdditionalUserInfo *unarchivedUserInfo = [NSKeyedUnarchiver unarchiveObjectWithData:data];
  XCTAssertTrue([unarchivedUserInfo isKindOfClass:[FIRAdditionalUserInfo class]],
                @"Unarchived object must be of kind FIRAdditionalUserInfo class.");
  XCTAssertEqualObjects(unarchivedUserInfo.providerID, userInfo.providerID);
  XCTAssertEqualObjects(unarchivedUserInfo.profile, userInfo.profile);
  XCTAssertEqualObjects(unarchivedUserInfo.username, userInfo.username);
  XCTAssertEqual(unarchivedUserInfo.isNewUser, unarchivedUserInfo.isNewUser);
}

@end

NS_ASSUME_NONNULL_END
