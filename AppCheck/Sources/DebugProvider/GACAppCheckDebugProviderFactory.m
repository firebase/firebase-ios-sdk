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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckDebugProviderFactory.h"

#import "AppCheck/Sources/Core/GACAppCheckLogger.h"
#import "AppCheck/Sources/Public/AppCheck/GACAppCheckDebugProvider.h"

NS_ASSUME_NONNULL_BEGIN

@implementation GACAppCheckDebugProviderFactory

- (nullable id<GACAppCheckProvider>)createProviderWithApp:(FIRApp *)app {
  GACAppCheckDebugProvider *provider = [[GACAppCheckDebugProvider alloc] initWithApp:app];

  // Print only locally generated token to avoid a valid token leak on CI.
  GACLogWarning(kFIRLoggerAppCheckMessageCodeDebugToken, @"Firebase App Check debug token: '%@'.",
                [provider localDebugToken]);

  return provider;
}

@end

NS_ASSUME_NONNULL_END
