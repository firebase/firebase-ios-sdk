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

#import "FirebaseAuth/Sources/Auth/FIRAuthDataResult_Internal.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend+MultiFactor.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentRequest.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactor+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorInfo+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorSession+Internal.h"
#import "FirebaseAuth/Sources/User/FIRUser_Internal.h"

#if TARGET_OS_IOS
#import "FirebaseAuth/Sources/AuthProvider/Phone/FIRPhoneAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/Phone/FIRPhoneMultiFactorAssertion+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/Phone/FIRPhoneMultiFactorInfo+Internal.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRPhoneMultiFactorAssertion.h"

#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPMultiFactorAssertion+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPMultiFactorInfo.h"
#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPSecret+Internal.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPMultiFactorAssertion.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPMultiFactorGenerator.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPSecret.h"

#endif

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

- (void)enrollWithAssertion:(FIRMultiFactorAssertion *)assertion
                displayName:(nullable NSString *)displayName
                 completion:(nullable FIRAuthVoidErrorCallback)completion {
#if TARGET_OS_IOS
  FIRFinalizeMFAEnrollmentRequest *request = nil;
  if ([assertion.factorID isEqualToString:FIRPhoneMultiFactorID]) {
    FIRPhoneMultiFactorAssertion *phoneAssertion = (FIRPhoneMultiFactorAssertion *)assertion;
    FIRAuthProtoFinalizeMFAPhoneRequestInfo *finalizeMFAPhoneRequestInfo =
        [[FIRAuthProtoFinalizeMFAPhoneRequestInfo alloc]
            initWithSessionInfo:phoneAssertion.authCredential.verificationID
               verificationCode:phoneAssertion.authCredential.verificationCode];
    request =
        [[FIRFinalizeMFAEnrollmentRequest alloc] initWithIDToken:self.user.rawAccessToken
                                                     displayName:displayName
                                           phoneVerificationInfo:finalizeMFAPhoneRequestInfo
                                            requestConfiguration:self.user.requestConfiguration];
  } else if ([assertion.factorID isEqualToString:FIRTOTPMultiFactorID]) {
    FIRTOTPMultiFactorAssertion *TOTPAssertion = (FIRTOTPMultiFactorAssertion *)assertion;
    FIRAuthProtoFinalizeMFATOTPEnrollmentRequestInfo *finalizeMFATOTPRequestInfo =
        [[FIRAuthProtoFinalizeMFATOTPEnrollmentRequestInfo alloc]
            initWithSessionInfo:TOTPAssertion.secret.sessionInfo
               verificationCode:TOTPAssertion.oneTimePassword];
    request =
        [[FIRFinalizeMFAEnrollmentRequest alloc] initWithIDToken:self.user.rawAccessToken
                                                     displayName:displayName
                                            TOTPVerificationInfo:finalizeMFATOTPRequestInfo
                                            requestConfiguration:self.user.requestConfiguration];
  }
  if (request == nil) {
    return;
  }
  [FIRAuthBackend
      finalizeMultiFactorEnrollment:request
                           callback:^(FIRFinalizeMFAEnrollmentResponse *_Nullable response,
                                      NSError *_Nullable error) {
                             if (error) {
                               if (completion) {
                                 completion(error);
                               }
                             } else {
                               [self.user.auth
                                   completeSignInWithAccessToken:response.IDToken
                                       accessTokenExpirationDate:nil
                                                    refreshToken:response.refreshToken
                                                       anonymous:NO
                                                        callback:^(FIRUser *_Nullable user,
                                                                   NSError *_Nullable error) {
                                                          FIRAuthDataResult *result =
                                                              [[FIRAuthDataResult alloc]
                                                                        initWithUser:user
                                                                  additionalUserInfo:nil];

                                                          FIRAuthDataResultCallback
                                                              decoratedCallback = [self.user.auth
                                                                  signInFlowAuthDataResultCallbackByDecoratingCallback:
                                                                      ^(FIRAuthDataResult
                                                                            *_Nullable authResult,
                                                                        NSError *_Nullable error) {
                                                                        if (completion) {
                                                                          completion(error);
                                                                        }
                                                                      }];
                                                          decoratedCallback(result, error);
                                                        }];
                             }
                           }];
#endif
}

- (void)unenrollWithInfo:(FIRMultiFactorInfo *)factorInfo
              completion:(nullable FIRAuthVoidErrorCallback)completion {
  [self unenrollWithFactorUID:factorInfo.UID completion:completion];
}

- (void)unenrollWithFactorUID:(NSString *)factorUID
                   completion:(nullable FIRAuthVoidErrorCallback)completion {
  FIRWithdrawMFARequest *request =
      [[FIRWithdrawMFARequest alloc] initWithIDToken:self.user.rawAccessToken
                                     MFAEnrollmentID:factorUID
                                requestConfiguration:self.user.requestConfiguration];
  [FIRAuthBackend
      withdrawMultiFactor:request
                 callback:^(FIRWithdrawMFAResponse *_Nullable response, NSError *_Nullable error) {
                   if (error) {
                     if (completion) {
                       completion(error);
                     }
                   } else {
                     [self.user.auth
                         completeSignInWithAccessToken:response.IDToken
                             accessTokenExpirationDate:nil
                                          refreshToken:response.refreshToken
                                             anonymous:NO
                                              callback:^(FIRUser *_Nullable user,
                                                         NSError *_Nullable error) {
                                                FIRAuthDataResult *result =
                                                    [[FIRAuthDataResult alloc] initWithUser:user
                                                                         additionalUserInfo:nil];
                                                FIRAuthDataResultCallback decoratedCallback = [FIRAuth
                                                                                                   .auth
                                                    signInFlowAuthDataResultCallbackByDecoratingCallback:
                                                        ^(FIRAuthDataResult *_Nullable authResult,
                                                          NSError *_Nullable error) {
                                                          if (error) {
                                                            [[FIRAuth auth] signOut:NULL];
                                                          }
                                                          if (completion) {
                                                            completion(error);
                                                          }
                                                        }];
                                                decoratedCallback(result, error);
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
      if (MFAEnrollment.TOTPInfo) {
        FIRMultiFactorInfo *multiFactorInfo =
            [[FIRTOTPMultiFactorInfo alloc] initWithProto:MFAEnrollment];
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
      [NSArray class], [FIRMultiFactorInfo class], [FIRPhoneMultiFactorInfo class],
      [FIRTOTPMultiFactorInfo class]
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
