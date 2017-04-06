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

#import "FIRPhoneAuthProvider.h"

#import "FIRPhoneAuthCredential_Internal.h"
#import "NSString+FIRAuth.h"
#import "../../Private/FIRAuthGlobalWorkQueue.h"
#import "../../Private/FIRAuth_Internal.h"
#import "../../Private/FIRAuthErrorUtils.h"
#import "FIRAuthBackend.h"
#import "FIRSendVerificationCodeRequest.h"
#import "FIRSendVerificationCodeResponse.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FIRPhoneAuthProvider {

  /** @var _auth
      @brief The auth instance used to for verifying the phone number.
   */
  FIRAuth *_auth;
}

/** @fn initWithAuth:
    @brief returns an instance of @c FIRPhoneAuthProvider assocaited with the provided auth
          instance.
    @return An Instance of @c FIRPhoneAuthProvider.
   */
- (nullable instancetype)initWithAuth:(FIRAuth *)auth {
  self = [super init];
  if (self) {
    _auth = auth;
  }
  return self;
}

- (void)verifyPhoneNumber:(NSString *)phoneNumber
               completion:(nullable FIRVerificationResultCallback)completion {
  dispatch_async(FIRAuthGlobalWorkQueue(), ^{
    if (!phoneNumber.length) {
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(nil, [FIRAuthErrorUtils missingPhoneNumberErrorWithMessage:nil]);
      });
      return;
    }
    FIRSendVerificationCodeRequest *request =
      [[FIRSendVerificationCodeRequest alloc]initWithPhoneNumber:phoneNumber APIKey:_auth.APIKey];
    [FIRAuthBackend sendVerificationCode:request
                                callback:^(FIRSendVerificationCodeResponse *_Nullable response,
                                           NSError *_Nullable error) {
      if (completion) {
        if (error) {
          dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil, error);
          });
          return;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
          // Associate the phone number with the verification ID.
          response.verificationID.fir_authPhoneNumber = phoneNumber;
          completion(response.verificationID, nil);
        });
      }
    }];
  });
}

- (FIRPhoneAuthCredential *)credentialWithVerificationID:(NSString *)verificationID
                                        verificationCode:(NSString *)verificationCode {
  return [[FIRPhoneAuthCredential alloc] initWithProviderID:FIRPhoneAuthProviderID
                                             verificationID:verificationID
                                           verificationCode:verificationCode];
}

+ (instancetype)provider {
  return [[self alloc]initWithAuth:[FIRAuth auth]];
}

+ (instancetype)providerWithAuth:(FIRAuth *)auth {
  return [[self alloc]initWithAuth:auth];
}

@end

NS_ASSUME_NONNULL_END
