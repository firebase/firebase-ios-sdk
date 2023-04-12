/*
 * Copyright 2023 Google
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

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPMultiFactorAssertion.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPMultiFactorGenerator.h"
#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRTOTPSecret.h"
#import "FirebaseAuth/Sources/MultiFactor/FIRMultiFactorSession+Internal.h"
#import "FIRTOTPSecret+Internal.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentResponse.h"
#import "FirebaseAuth/Sources/Backend/RPC/MultiFactor/Enroll/FIRStartMFAEnrollmentRequest.h"
#import "FirebaseAuth/Sources/Backend/RPC/Proto/TOTP/FIRAuthProtoStartMFATOTPEnrollmentResponseInfo.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend+MultiFactor.h"
#import "FirebaseAuth/Sources/Backend/FIRAuthBackend.h"
#import "FirebaseAuth/Sources/Auth/FIRAuth_Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPSecret+Internal.h"
#import "FirebaseAuth/Sources/MultiFactor/TOTP/FIRTOTPMultiFactorAssertion+Internal.h"

@implementation FIRTOTPMultiFactorGenerator

+(FIRTOTPSecret *)generateSecretWithMultiFactorSession:(FIRMultiFactorSession *)session {
	if (session.IDToken) {
		FIRStartMFAEnrollmentRequest *request =
		[[FIRStartMFAEnrollmentRequest alloc] initWithIDToken:session.IDToken TOTPEnrollmentInfo:[[FIRAuthProtoStartMFATOTPEnrollmentRequestInfo alloc] init] requestConfiguration: session.auth.requestConfiguration];
		__block FIRTOTPSecret *secret = nil;
		[FIRAuthBackend startMultiFactorEnrollment:request callback:^(FIRStartMFAEnrollmentResponse  *_Nullable response, NSError *_Nullable error) {
			if(error) {
				//handle error
			} else {
				if(response.TOTPSessionInfo) {
					secret = [[FIRTOTPSecret alloc]initWithSecretKey:response.TOTPSessionInfo.sharedSecretKey hashingAlgorithm:response.TOTPSessionInfo.hashingAlgorithm codeLength:response.TOTPSessionInfo.verificationCodeLength codeIntervalSeconds:response.TOTPSessionInfo.periodSec enrollmentCompletionDeadline:response.TOTPSessionInfo.finalizeEnrollmentTime sessionInfo:response.TOTPSessionInfo.sessionInfo];
				}
			}
		}];
		return secret;
	}
	return nil;
}

+(FIRTOTPMultiFactorAssertion *)assertionForEnrollmentWithSecret: (FIRTOTPSecret *)secret
																								 oneTimePassword: (NSString *)oneTimePassword {
	FIRTOTPMultiFactorAssertion *assertion = [[FIRTOTPMultiFactorAssertion alloc] initWithSecret:secret oneTimePassword:oneTimePassword];
	return assertion;
}

+(FIRTOTPMultiFactorAssertion *)assertionForSignInWithEnrollmentID:(NSString *)enrollmentID
																									 oneTimePassword:(NSString *)oneTimePassword{
	return nil;
}
@end

#endif
