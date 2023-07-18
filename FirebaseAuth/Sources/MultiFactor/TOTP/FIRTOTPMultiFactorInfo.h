/*
 * Copyright 2023 Google LLC
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

#import <Foundation/Foundation.h>

#import "FirebaseAuth/Sources/Public/FirebaseAuth/FIRMultiFactorInfo.h"

NS_ASSUME_NONNULL_BEGIN

@class FIRAuthProtoMFAEnrollment;

/**
 @class FIRTotpMultiFactorInfo
 @brief Extends the MultiFactorInfo class for time based one-time password second factors.
        The identifier of this second factor is "totp".
        This class is available on iOS only.
*/
NS_SWIFT_NAME(TOTPMultiFactorInfo) API_UNAVAILABLE(macos, tvos, watchos)
    @interface FIRTOTPMultiFactorInfo : FIRMultiFactorInfo

/**
 @brief This is the totp info for the second factor.
*/
@property(nonatomic, readonly, nullable) NSObject *TOTPInfo;

/**
 @fn initWithProto:
 @brief Initilize the FIRAuthProtoMFAEnrollment instance with proto.
 @param proto FIRAuthProtoMFAEnrollment proto object.
*/
- (instancetype)initWithProto:(FIRAuthProtoMFAEnrollment *)proto;

@end

NS_ASSUME_NONNULL_END
