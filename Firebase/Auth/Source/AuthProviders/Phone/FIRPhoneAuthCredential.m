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

#import "FIRPhoneAuthCredential.h"

#import "FIRPhoneAuthCredential_Internal.h"
#import "FIRAuthCredential_Internal.h"
#import "FIRAuthExceptionUtils.h"
#import "FIRVerifyAssertionRequest.h"

NS_ASSUME_NONNULL_BEGIN

@interface FIRPhoneAuthCredential ()

- (nullable instancetype)initWithProvider:(NSString *)provider NS_UNAVAILABLE;

@end

@implementation FIRPhoneAuthCredential

- (instancetype)initWithTemporaryProof:(NSString *)temporaryProof
                           phoneNumber:(NSString *)phoneNumber
                            providerID:(NSString *)providerID {
  self = [super initWithProvider:providerID];
  if (self) {
    _temporaryProof = [temporaryProof copy];
    _phoneNumber = [phoneNumber copy];
  }
  return self;
}

- (nullable instancetype)initWithProvider:(NSString *)provider {
  [FIRAuthExceptionUtils raiseMethodNotImplementedExceptionWithReason:
      @"Please call the designated initializer."];
  return nil;
}

- (instancetype)initWithProviderID:(NSString *)providerID
                    verificationID:(NSString *)verificationID
                  verificationCode:(NSString *)verificationCode {
  self = [super initWithProvider:providerID];
  if (self) {
    _verificationID = [verificationID copy];
    _verificationCode = [verificationCode copy];
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
