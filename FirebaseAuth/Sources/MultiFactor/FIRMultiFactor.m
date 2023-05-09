/*
 * Copyright 2019 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
#import <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactor.h"

#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactor+Internal.h"

#import "FirebaseAuth-Swift.h"

typedef void (^FIRAuthDataResultCallback)(FIRAuthDataResult *_Nullable authResult,
                                          NSError *_Nullable error);

NS_ASSUME_NONNULL_BEGIN

static NSString *kEnrolledFactorsCodingKey = @"enrolledFactors";

static NSString *kUserCodingKey = @"user";

@implementation FIRMultiFactor

- (void)getSessionWithCompletion:(nullable FIRMultiFactorSessionCallback)completion {
  FIRMultiFactorSession *session = [FIRMultiFactorSession sessionForCurrentUser];
  if (completion) {
    completion(session, nil);
  }
}

typedef void (^FIRAuthVoidErrorCallback)(NSError *_Nullable);
- (void)enrollWithAssertion:(FIRMultiFactorAssertion *)assertion
                displayName:(nullable NSString *)displayName
                 completion:(nullable FIRAuthVoidErrorCallback)completion {
#if TARGET_OS_IOS
  FIRPhoneMultiFactorAssertion *phoneAssertion = (FIRPhoneMultiFactorAssertion *)assertion;
  FIRAuthProtoFinalizeMFAPhoneRequestInfo *finalizeMFAPhoneRequestInfo =
      [[FIRAuthProtoFinalizeMFAPhoneRequestInfo alloc]
          initWithSessionInfo:phoneAssertion.authCredential.verificationID
             verificationCode:phoneAssertion.authCredential.verificationCode];
  FIRFinalizeMFAEnrollmentRequest *request =
      [[FIRFinalizeMFAEnrollmentRequest alloc] initWithIDToken:self.user.tokenService.accessToken
                                                   displayName:displayName
                                              verificationInfo:finalizeMFAPhoneRequestInfo
                                          requestConfiguration:self.user.requestConfiguration];
//  [FIRAuthBackend2
//      postWithRequest:request
//             callback:^(FIRFinalizeMFAEnrollmentResponse *_Nullable response,
//                        NSError *_Nullable error) {
//               if (error) {
//                 if (completion) {
//                   completion(error);
//                 }
//               } else {
//                 [FIRAuth.auth
//                     completeSignInWithAccessToken:response.IDToken
//                         accessTokenExpirationDate:nil
//                                      refreshToken:response.refreshToken
//                                         anonymous:NO
//                                          callback:^(FIRUser *_Nullable user,
//                                                     NSError *_Nullable error) {
//                                            FIRAuthDataResult *result =
//                                                [[FIRAuthDataResult alloc] initWithUser:user
//                                                                     additionalUserInfo:nil
//                                                                             credential:nil];
//                                            FIRAuthDataResultCallback decoratedCallback = [FIRAuth
//                                                                                               .auth
//                                                signInFlowAuthDataResultCallbackByDecoratingCallback:
//                                                    ^(FIRAuthDataResult *_Nullable authResult,
//                                                      NSError *_Nullable error) {
//                                                      if (completion) {
//                                                        completion(error);
//                                                      }
//                                                    }];
//                                            decoratedCallback(result, error);
//                                          }];
//               }
//             }];
#endif
}

- (void)unenrollWithInfo:(FIRMultiFactorInfo *)factorInfo
              completion:(nullable FIRAuthVoidErrorCallback)completion {
  [self unenrollWithFactorUID:factorInfo.UID completion:completion];
}

- (void)unenrollWithFactorUID:(NSString *)factorUID
                   completion:(nullable FIRAuthVoidErrorCallback)completion {
  FIRWithdrawMFARequest *request =
      [[FIRWithdrawMFARequest alloc] initWithIDToken:self.user.tokenService.accessToken
                                     MFAEnrollmentID:factorUID
                                requestConfiguration:self.user.requestConfiguration];
  [FIRAuthBackend2
      postWithRequest:request
             callback:^(FIRWithdrawMFAResponse *_Nullable response, NSError *_Nullable error) {
               if (error) {
                 if (completion) {
                   completion(error);
                 }
               } else {
                 [FIRAuth.auth completeSignInWithAccessToken:response.IDToken
                                   accessTokenExpirationDate:nil
                                                refreshToken:response.refreshToken
                                                   anonymous:NO
                                                    callback:^(FIRUser *_Nullable user,
                                                               NSError *_Nullable error) {
                                                      FIRAuthDataResult *result =
                                                          [[FIRAuthDataResult alloc]
                                                                    initWithUser:user
                                                              additionalUserInfo:nil
                                                                      credential:nil];
                                                      //                                            FIRAuthDataResultCallback decoratedCallback = [FIRAuth
                                                      //                                                                                               .auth
                                                      //                                                signInFlowAuthDataResultCallbackByDecoratingCallback:
                                                      //                                                    ^(FIRAuthDataResult *_Nullable authResult,
                                                      //                                                      NSError *_Nullable error) {
                                                      //                                                      if (error) {
                                                      //                                                        [[FIRAuth auth] signOut:NULL];
                                                      //                                                      }
                                                      //                                                      if (completion) {
                                                      //                                                        completion(error);
                                                      //                                                      }
                                                      //                                                    }];
                                                      //                                            decoratedCallback(result, error);
                                                    }];
               }
             }];
}

#pragma mark - Internal

- (instancetype)initWithMFAEnrollments:(NSArray<FIRAuthProtoMFAEnrollment *> *)MFAEnrollments {
  self = [super init];

  if (self) {
    NSMutableArray<FIRMultiFactorInfo *> *multiFactorInfoArray = [[NSMutableArray alloc] init];
    for (FIRAuthProtoMFAEnrollment *MFAEnrollment in MFAEnrollments) {
      if (MFAEnrollment.phoneInfo) {
        FIRMultiFactorInfo *multiFactorInfo =
            [[FIRPhoneMultiFactorInfo alloc] initWithProto:MFAEnrollment];
        [multiFactorInfoArray addObject:multiFactorInfo];
      }
    }
    _enrolledFactors = [multiFactorInfoArray copy];
  }

  return self;
}

#pragma mark - NSSecureCoding

+ (BOOL)supportsSecureCoding {
  return YES;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
  self = [self init];
  if (self) {
    NSSet *enrolledFactorsClasses = [NSSet setWithArray:@[
      [NSArray class], [FIRMultiFactorInfo class], [FIRPhoneMultiFactorInfo class]
    ]];
    NSArray<FIRMultiFactorInfo *> *enrolledFactors =
        [aDecoder decodeObjectOfClasses:enrolledFactorsClasses forKey:kEnrolledFactorsCodingKey];
    _enrolledFactors = enrolledFactors;
    // Do not decode `user` weak property.
  }
  return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
  [aCoder encodeObject:_enrolledFactors forKey:kEnrolledFactorsCodingKey];
  // Do not encode `user` weak property.
}

@end

NS_ASSUME_NONNULL_END

#endif
