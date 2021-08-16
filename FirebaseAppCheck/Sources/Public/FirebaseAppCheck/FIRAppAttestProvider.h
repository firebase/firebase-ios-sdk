/*
 * Copyright 2021 Google LLC
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

#import "FIRAppCheckProvider.h"

#import "FIRAppCheckAvailability.h"

@class FIRApp;

NS_ASSUME_NONNULL_BEGIN

FIR_APP_ATTEST_PROVIDER_AVAILABILITY
NS_SWIFT_NAME(AppAttestProvider)
@interface FIRAppAttestProvider : NSObject <FIRAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithApp:(FIRApp *)app;

@end

NS_ASSUME_NONNULL_END
