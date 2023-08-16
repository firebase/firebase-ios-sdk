/*
 * Copyright 2022 Google LLC
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

#import <Foundation/Foundation.h>

#import "FirebaseAuth/Sources/Backend/FIRAuthRPCResponse.h"

NS_ASSUME_NONNULL_BEGIN

/** @class FIRVerifyPasswordResponse
    @brief Represents the response from the getRecaptchaConfig endpoint.
 */
@interface FIRGetRecaptchaConfigResponse : NSObject <FIRAuthRPCResponse>

/** @property recaptchaKey
    @brief The recaptcha key of the project.
 */
@property(nonatomic, copy, nullable) NSString *recaptchaKey;

/** @property enforcementState
    @brief The enforcement state array.
 */
@property(nonatomic, nullable) NSArray *enforcementState;

@end

NS_ASSUME_NONNULL_END
