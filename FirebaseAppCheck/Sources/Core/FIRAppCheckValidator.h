/*
 * Copyright 2020 Google LLC
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

@class FIROptions;

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppCheckValidator : NSObject

// `FIRAppCheckValidator` doesn’t provide any instance methods.
- (instancetype)init NS_UNAVAILABLE;

/** The method validates if all parameters required to send App Check token exchange requests are
 * present in the `FIROptions` instance.
 *  @param options The `FIROptions` to validate.
 *  @return The array with missing field names. The array is empty when all required parameters are
 * present.
 */
+ (NSArray<NSString *> *)tokenExchangeMissingFieldsInOptions:(FIROptions *)options;

@end

NS_ASSUME_NONNULL_END
