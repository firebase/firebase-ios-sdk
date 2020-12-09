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

#import "FIRAppCheckProvider.h"

@class FIRApp;
@protocol FIRAppCheckDebugProviderAPIServiceProtocol;

NS_ASSUME_NONNULL_BEGIN

// TODO: Add more detailed documentation on how to use the debug provider.

@interface FIRAppCheckDebugProvider : NSObject <FIRAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;

- (nullable instancetype)initWithApp:(FIRApp *)app;

- (instancetype)initWithAPIService:(id<FIRAppCheckDebugProviderAPIServiceProtocol>)APIService;

/** Return the locally generated token. */
- (NSString *)localDebugToken;

/** Returns the currently used App Check debug token. The priority:
 *  - `FIRAAppCheckDebugToken` env variable value
 *  - previously generated stored local token
 *  - newly generated random token
 * @return The currently used App Check debug token.
 */
- (NSString *)currentDebugToken;

@end

NS_ASSUME_NONNULL_END
