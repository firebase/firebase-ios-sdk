/*
 * Copyright 2020 Google LLC
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

#import <OCMock/OCMock.h>
#import <XCTest/XCTest.h>

#import "FirebaseInAppMessaging/Sources/Private/Analytics/FIRIAMClientInfoFetcher.h"
#import "FirebaseInAppMessaging/Sources/Runtime/FIRIAMSDKRuntimeErrorCodes.h"

#import "FirebaseInstallations/Source/Library/Private/FirebaseInstallationsInternal.h"

@interface FIRInstallationsAuthTokenResult (Tests)
- (instancetype)initWithToken:(NSString *)token expirationDate:(NSDate *)expirationDate;
@end

@interface FIRIAMClientInfoFetcherTests : XCTestCase

@property(nonatomic, strong) FIRIAMClientInfoFetcher *clientInfoFetcher;
@property(nonatomic) id mockInstallations;

@end

@implementation FIRIAMClientInfoFetcherTests

- (void)setUp {
  self.mockInstallations = OCMClassMock([FIRInstallations class]);
  self.clientInfoFetcher =
      [[FIRIAMClientInfoFetcher alloc] initWithFirebaseInstallations:self.mockInstallations];
}

- (void)tearDown {
  [self.mockInstallations stopMocking];
}

- (void)testNoInstallations {
  FIRIAMClientInfoFetcher *fetcherWithoutInstallations =
      [[FIRIAMClientInfoFetcher alloc] initWithFirebaseInstallations:nil];

  [fetcherWithoutInstallations
      fetchFirebaseInstallationDataWithProjectNumber:@"my project number"
                                      withCompletion:^(NSString *_Nullable FID,
                                                       NSString *_Nullable FISToken,
                                                       NSError *_Nullable error) {
                                        XCTAssertEqual(
                                            error.code,
                                            FIRIAMSDKRuntimeErrorNoFirebaseInstallationsObject);
                                      }];
}

- (void)testReturnsBothFIDAndToken {
  FIRInstallationsAuthTokenResult *tokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"mock_token"
                                              expirationDate:[NSDate distantFuture]];
  [self mockInstanceIDMethodForTokenAndIdentity:tokenResult
                                     tokenError:nil
                                       identity:@"mock_id"
                                  identityError:nil];

  [self.clientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:@"my project number"
                                      withCompletion:^(NSString *_Nullable FID,
                                                       NSString *_Nullable FISToken,
                                                       NSError *_Nullable error) {
                                        XCTAssertEqualObjects(FID, @"mock_id");
                                        XCTAssertEqualObjects(FISToken, @"mock_token");
                                        XCTAssertNil(error);
                                      }];
}

- (void)testReturnsTokenButNotFID {
  // Mock error where no installations ID was fetched.
  NSError *error =
      [NSError errorWithDomain:@"com.mock.installations"
                          code:0
                      userInfo:@{NSLocalizedDescriptionKey : @"Installations couldn't return FID"}];

  FIRInstallationsAuthTokenResult *tokenResult =
      [[FIRInstallationsAuthTokenResult alloc] initWithToken:@"mock_token"
                                              expirationDate:[NSDate distantFuture]];
  [self mockInstanceIDMethodForTokenAndIdentity:tokenResult
                                     tokenError:nil
                                       identity:nil
                                  identityError:error];

  [self.clientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:@"my project number"
                                      withCompletion:^(NSString *_Nullable FID,
                                                       NSString *_Nullable FISToken,
                                                       NSError *_Nullable error) {
                                        // FID should be nil.
                                        XCTAssertNil(FID);
                                        // FIS token is still passed.
                                        XCTAssertEqualObjects(FISToken, @"mock_token");
                                        // Validate error gets propagated.
                                        XCTAssertEqualObjects(error.localizedDescription,
                                                              @"Installations couldn't return FID");
                                      }];
}

- (void)testDoesntReturnToken {
  // Mock error where no auth token was fetched.
  NSError *error = [NSError
      errorWithDomain:@"com.mock.installations"
                 code:0
             userInfo:@{NSLocalizedDescriptionKey : @"Installations couldn't return FIS token"}];

  [self mockInstanceIDMethodForTokenAndIdentity:nil
                                     tokenError:error
                                       identity:nil
                                  identityError:nil];

  [self.clientInfoFetcher
      fetchFirebaseInstallationDataWithProjectNumber:@"my project number"
                                      withCompletion:^(NSString *_Nullable FID,
                                                       NSString *_Nullable FISToken,
                                                       NSError *_Nullable error) {
                                        XCTAssertNil(FID);
                                        XCTAssertNil(FISToken);
                                        // Validate error gets propagated.
                                        XCTAssertEqualObjects(
                                            error.localizedDescription,
                                            @"Installations couldn't return FIS token");
                                      }];
}

// Mock FIRInstallations methods.
- (void)mockInstanceIDMethodForTokenAndIdentity:
            (nullable FIRInstallationsAuthTokenResult *)tokenResult
                                     tokenError:(nullable NSError *)tokenError
                                       identity:(nullable NSString *)identity
                                  identityError:(nullable NSError *)identityError {
  OCMStub([self.mockInstallations
      installationIDWithCompletion:([OCMArg
                                       invokeBlockWithArgs:(identity ? identity : [NSNull null]),
                                                           (identityError ? identityError
                                                                          : [NSNull null]),
                                                           nil])]);
  OCMStub([self.mockInstallations
      authTokenWithCompletion:([OCMArg
                                  invokeBlockWithArgs:(tokenResult ? tokenResult : [NSNull null]),
                                                      (tokenError ? tokenError : [NSNull null]),
                                                      nil])]);
}

@end
