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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRAdditionalUserInfo.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorResolver.h"

#import "FirebaseAuth/Sources/Auth/FIRAuthDataResult_Internal.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend+MultiFactor.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/SignIn/FIRFinalizeMFASignInRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/Phone/FIRAuthProtoFinalizeMFAPhoneRequestInfo.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoFinalizeMFATOTPSignInRequestInfo.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorResolver+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorSession+Internal.h"

#if TARGET_OS_IOS
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRPhoneMultiFactorAssertion.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPMultiFactorAssertion.h"

#import "FirebaseAuth/Sources/AuthProvider/Phone/FIRPhoneAuthCredential_Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/Phone/FIRPhoneMultiFactorAssertion+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPMultiFactorAssertion+Internal.h"

#endif

NS_ASSUME_NONNULL_BEGIN

@implementation FIRMultiFactorResolver

- (instancetype)initWithMFAPendingCredential:(NSString *_Nullable)MFAPendingCredential
                                       hints:(NSArray<FIRMultiFactorInfo *> *)hints
                                        auth:(FIRAuth *)auth {
  self = [super init];
  if (self) {
    _MFAPendingCredential = MFAPendingCredential;
    _hints = hints;
    _auth = auth;
    _session = [[FIRMultiFactorSession alloc] init];
    _session.MFAPendingCredential = MFAPendingCredential;
  }
  return self;
}

- (void)resolveSignInWithAssertion:(nonnull FIRMultiFactorAssertion *)assertion
                        completion:(nullable FIRAuthDataResultCallback)completion {
#if TARGET_OS_IOS
  NSObject<FIRAuthProto> *finalizedMFARequestInfo;
  if ([assertion isKindOfClass:[FIRPhoneMultiFactorAssertion class]]) {
    FIRPhoneMultiFactorAssertion *phoneAssertion = (FIRPhoneMultiFactorAssertion *)assertion;
    finalizedMFARequestInfo = [[FIRAuthProtoFinalizeMFAPhoneRequestInfo alloc]
        initWithSessionInfo:phoneAssertion.authCredential.verificationID
           verificationCode:phoneAssertion.authCredential.verificationCode];
  } else if ([assertion isKindOfClass:[FIRTOTPMultiFactorAssertion class]]) {
    FIRTOTPMultiFactorAssertion *totpAssertion = (FIRTOTPMultiFactorAssertion *)assertion;
    finalizedMFARequestInfo = [[FIRAuthProtoFinalizeMFATOTPSignInRequestInfo alloc]
        initWithMfaEnrollmentID:totpAssertion.enrollmentID
               verificationCode:totpAssertion.oneTimePassword];
  }
  if (finalizedMFARequestInfo != nil) {
    FIRFinalizeMFASignInRequest *request = [[FIRFinalizeMFASignInRequest alloc]
        initWithMFAPendingCredential:self.MFAPendingCredential
                    verificationInfo:finalizedMFARequestInfo
                requestConfiguration:self.auth.requestConfiguration];
    [FIRAuthBackend
        finalizeMultiFactorSignIn:request
                         callback:^(FIRFinalizeMFASignInResponse *_Nullable response,
                                    NSError *_Nullable error) {
                           if (error) {
                             if (completion) {
                               completion(nil, error);
                             }
                           } else {
                             [self.auth
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
                                                            decoratedCallback = [self.auth
                                                                signInFlowAuthDataResultCallbackByDecoratingCallback:
                                                                    completion];
                                                        decoratedCallback(result, error);
                                                      }];
                           }
                         }];
  }

#endif
}

@end

NS_ASSUME_NONNULL_END

#endif
