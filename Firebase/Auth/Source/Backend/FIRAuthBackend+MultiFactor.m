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

#import "FIRAuthBackend+MultiFactor.h"

@implementation FIRAuthBackend (MultiFactor)

+ (void)startMultiFactorEnrollment:(FIRStartMfaEnrollmentRequest *)request
                          callback:(FIRStartMfaEnrollmentResponseCallback)callback {
  FIRStartMfaEnrollmentResponse *response = [[FIRStartMfaEnrollmentResponse alloc] init];
  [[self implementation] postWithRequest:request response:response callback:^(NSError *error) {
    if (error) {
      callback(nil, error);
    } else {
      callback(response, nil);
    }
  }];
}

+ (void)finalizeMultiFactorEnrollment:(FIRFinalizeMfaEnrollmentRequest *)request
                             callback:(FIRFinalizeMfaEnrollmentResponseCallback)callback {
  FIRFinalizeMfaEnrollmentResponse *response = [[FIRFinalizeMfaEnrollmentResponse alloc] init];
  [[self implementation] postWithRequest:request response:response callback:^(NSError *error) {
    if (error) {
      callback(nil, error);
    } else {
      callback(response, nil);
    }
  }];
}

+ (void)startMultiFactorSignIn:(FIRStartMfaSignInRequest *)request
                      callback:(FIRStartMfaSignInResponseCallback)callback {
  FIRStartMfaSignInResponse *response = [[FIRStartMfaSignInResponse alloc] init];
  [[self implementation] postWithRequest:request response:response callback:^(NSError *error) {
    if (error) {
      callback(nil, error);
    } else {
      callback(response, nil);
    }
  }];
}

+ (void)finalizeMultiFactorSignIn:(FIRFinalizeMfaSignInRequest *)request
                         callback:(FIRFinalizeMfaSignInResponseCallback)callback {
  FIRFinalizeMfaSignInResponse *response = [[FIRFinalizeMfaSignInResponse alloc] init];
  [[self implementation] postWithRequest:request response:response callback:^(NSError *error) {
    if (error) {
      callback(nil, error);
    } else {
      callback(response, nil);
    }
  }];
}

+ (void)withdrawMultiFactor:(FIRWithdrawMfaRequest *)request
                   callback:(FIRWithdrawMfaResponseCallback)callback {
  FIRWithdrawMfaResponse *response = [[FIRWithdrawMfaResponse alloc] init];
  [[self implementation] postWithRequest:request response:response callback:^(NSError *error) {
    if (error) {
      callback(nil, error);
    } else {
      callback(response, nil);
    }
  }];
}

@end
