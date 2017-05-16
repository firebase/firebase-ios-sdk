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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** @category NSString(FIRAuth)
    @brief A FIRAuth category for extending the functionality of NSString for specific Firebase Auth
        use cases.
 */
@interface NSString (FIRAuth)

/** @property fir_authPhoneNumber
    @brief A phone number associated with the verification ID (NSString instance).
    @remarks Allows an instance on NSString to be associated with a phone number in order to link
        phone number with the verificationID returned from verifyPhoneNumber:completion:
 */
@property(nonatomic, strong) NSString *fir_authPhoneNumber;

@end

NS_ASSUME_NONNULL_END
