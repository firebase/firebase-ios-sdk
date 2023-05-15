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

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckAvailability.h"

#if GAC_DEVICE_CHECK_SUPPORTED_TARGETS

#import "AppCheck/Sources/Public/AppCheck/GACDeviceCheckProviderFactory.h"

#import "AppCheck/Sources/Public/AppCheck/GACAppCheckProvider.h"
#import "AppCheck/Sources/Public/AppCheck/GACDeviceCheckProvider.h"

@implementation GACDeviceCheckProviderFactory

- (nullable id<GACAppCheckProvider>)createProviderWithApp:(nonnull FIRApp *)app {
  return [[GACDeviceCheckProvider alloc] initWithApp:app];
}

@end

#endif  // GAC_DEVICE_CHECK_SUPPORTED_TARGETS
