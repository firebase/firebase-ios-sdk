/*
 * Copyright 2021 Google
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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIROtpMultiFactorAssertion.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIROtpMultiFactorGenerator.h"

#import "FirebaseAuth/Sources/MultiFactor/Otp/FIROtpMultiFactorAssertion+Internal.h"

#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorSession+Internal.h"

#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/Otp/FIRAuthProtoStartMFAOtpRequestInfo.h"

#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"

#import "FirebaseAuth/Sources/Backend/FIRAuthBackend+MultiFactor.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"

#import "FirebaseAuth/Sources/Utilities/FIRAuthErrorUtils.h"

@implementation FIROtpMultiFactorGenerator

+ (FIROtpMultiFactorAssertion *)assertionWithMFAEnrollmentID:(NSString *)MFAEnrollmentID
                                            verificationCode:(NSString *)verificationCode {
  FIROtpMultiFactorAssertion *assertion = [[FIROtpMultiFactorAssertion alloc] init];
  assertion.MFAEnrollmentID = MFAEnrollmentID;
  assertion.verificationCode = verificationCode;
  return assertion;
}

+ (FIROtpMultiFactorAssertion *)assertionWithSessionInfo:(NSString *)sessionInfo
                                        verificationCode:(NSString *)verificationCode {
  FIROtpMultiFactorAssertion *assertion = [[FIROtpMultiFactorAssertion alloc] init];
  assertion.sessionInfo = sessionInfo;
  assertion.verificationCode = verificationCode;
  return assertion;
}

+ (NSString *)generateKeyWithMultiFactorSession:(nullable FIRMultiFactorSession *)session
                                     completion:(nullable FIRMultiFactorOTPSessionCallback)callback {
  if (!session) {
    return @"failed";
  }

  NSString *IDToken = session.IDToken;
  FIRAuthProtoStartMFAOtpRequestInfo *startMFARequestInfo =
  [[FIRAuthProtoStartMFAOtpRequestInfo alloc] initWithEnabled:TRUE];

  FIRStartMFAEnrollmentRequest *request = [[FIRStartMFAEnrollmentRequest alloc]
                                           initWithIDToken:IDToken
                                           otpEnrollmentInfo:startMFARequestInfo
                                           requestConfiguration:[FIRAuth auth].requestConfiguration];

  [FIRAuthBackend startMultiFactorEnrollment:request
                                    callback:^(FIRStartMFAEnrollmentResponse
                                               *_Nullable response,
                                               NSError *_Nullable error) {
    if (error) {
      if (error.code ==
          FIRAuthErrorCodeInvalidAppCredential) {
        // TODO: Implement retry
        if (callback) {
          callback(
                   nil,
                   nil,
                   [FIRAuthErrorUtils
                    unexpectedResponseWithDeserializedResponse:
                    nil
                    underlyingError:
                    error]);
        }
        return;
      } else {
        if (callback) {
          callback(nil, nil, error);
        }
      }
    } else {
      if (callback) {
        callback(
                 response.otpEnrollmentResponse.key,
                 response.otpEnrollmentResponse.sessionInfo,
                 nil);
      }
    }
  }];

  return @"key";
}

@end

#endif
