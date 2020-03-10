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

#include <TargetConditionals.h>
#if TARGET_OS_IOS

#import "FIRAuthBackend.h"

#import "FIRStartMfaEnrollmentRequest.h"
#import "FIRStartMfaEnrollmentResponse.h"
#import "FIRFinalizeMfaEnrollmentRequest.h"
#import "FIRFinalizeMfaEnrollmentResponse.h"
#import "FIRStartMfaSignInRequest.h"
#import "FIRStartMfaSignInResponse.h"
#import "FIRFinalizeMfaSignInRequest.h"
#import "FIRFinalizeMfaSignInResponse.h"
#import "FIRWithdrawMfaRequest.h"
#import "FIRWithdrawMfaResponse.h"

NS_ASSUME_NONNULL_BEGIN

/** @typedef FIRStartMfaEnrollmentResponseCallback
    @brief The type of block used to return the result of a call to the startMfaEnroll endpoint.
    @param response The received response, if any.
    @param error The error which occurred, if any.
    @remarks One of response or error will be non-nil.
*/
typedef void (^FIRStartMfaEnrollmentResponseCallback)
(FIRStartMfaEnrollmentResponse *_Nullable response, NSError *_Nullable error);

/** @typedef FIRFinalizeMfaEnrollmentResponseCallback
    @brief The type of block used to return the result of a call to the finalizeMfaEnroll endpoint.
    @param response The received response, if any.
    @param error The error which occurred, if any.
    @remarks One of response or error will be non-nil.
*/
typedef void (^FIRFinalizeMfaEnrollmentResponseCallback)
(FIRFinalizeMfaEnrollmentResponse *_Nullable response, NSError *_Nullable error);

/** @typedef FIRStartMfaSignInResponseCallback
    @brief The type of block used to return the result of a call to the startMfaSignIn endpoint.
    @param response The received response, if any.
    @param error The error which occurred, if any.
    @remarks One of response or error will be non-nil.
*/
typedef void (^FIRStartMfaSignInResponseCallback)
(FIRStartMfaSignInResponse *_Nullable response, NSError *_Nullable error);

/** @typedef FIRFinalizeMfaSignInResponseCallback
    @brief The type of block used to return the result of a call to the finalizeMfaSignIn endpoint.
    @param response The received response, if any.
    @param error The error which occurred, if any.
    @remarks One of response or error will be non-nil.
*/
typedef void (^FIRFinalizeMfaSignInResponseCallback)
(FIRFinalizeMfaSignInResponse *_Nullable response, NSError *_Nullable error);

/** @typedef FIRWithdrawMfaResponseCallback
    @brief The type of block used to return the result of a call to the mfaUnenroll endpoint.
    @param response The received response, if any.
    @param error The error which occurred, if any.
    @remarks One of response or error will be non-nil.
*/
typedef void (^FIRWithdrawMfaResponseCallback)
(FIRWithdrawMfaResponse *_Nullable response, NSError *_Nullable error);

@interface FIRAuthBackend (MultiFactor)

/** @fn startMultiFactorEnrollment:callback:
    @brief Calls the startMfaEnrollment endpoint.
    @param request The request parameters.
    @param callback The callback.
*/
+ (void)startMultiFactorEnrollment:(FIRStartMfaEnrollmentRequest *)request
                          callback:(FIRStartMfaEnrollmentResponseCallback)callback;

/** @fn finalizeMultiFactorEnrollment:callback:
    @brief Calls the finalizeMultiFactorEnrollment endpoint.
    @param request The request parameters.
    @param callback The callback.
*/
+ (void)finalizeMultiFactorEnrollment:(FIRFinalizeMfaEnrollmentRequest *)request
                             callback:(FIRFinalizeMfaEnrollmentResponseCallback)callback;

/** @fn startMultiFactorSignIn:callback:
    @brief Calls the startMultiFactorSignIn endpoint.
    @param request The request parameters.
    @param callback The callback.
*/
+ (void)startMultiFactorSignIn:(FIRStartMfaSignInRequest *)request
                      callback:(FIRStartMfaSignInResponseCallback)callback;

/** @fn finalizeMultiFactorSignIn:callback:
    @brief Calls the finalizeMultiFactorSignIn endpoint.
    @param request The request parameters.
    @param callback The callback.
*/
+ (void)finalizeMultiFactorSignIn:(FIRFinalizeMfaSignInRequest *)request
                         callback:(FIRFinalizeMfaSignInResponseCallback)callback;

/** @fn withdrawMultiFactor:callback:
    @brief Calls the withdrawMultiFactor endpoint.
    @param request The request parameters.
    @param callback The callback.
*/
+ (void)withdrawMultiFactor:(FIRWithdrawMfaRequest *)request
                   callback:(FIRWithdrawMfaResponseCallback)callback;

@end

NS_ASSUME_NONNULL_END

#endif
