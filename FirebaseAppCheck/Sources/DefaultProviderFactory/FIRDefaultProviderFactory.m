// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseAppCheck/Sources/DefaultProviderFactory/FIRDefaultProviderFactory.h"

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"
#import "FirebaseAppCheck/Sources/Core/FIRAppCheckLogger.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheck.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRAppCheckDebugProviderFactory.h"
#import "FirebaseAppCheck/Sources/Public/FirebaseAppCheck/FIRDeviceCheckProviderFactory.h"

@implementation FIRDefaultProviderFactory

+ (void)load {
  [FIRAppCheck setAppCheckProviderFactory:[[self alloc] init]];
}

- (nullable id<FIRAppCheckProvider>)createProviderWithApp:(nonnull FIRApp *)app {
#if TARGET_OS_SIMULATOR
  return [[[FIRAppCheckDebugProviderFactory alloc] init] createProviderWithApp:app];
#else  // !TARGET_OS_SIMULATOR

  if (@available(watchOS 9.0, *)) {
    return [[[FIRDeviceCheckProviderFactory alloc] init] createProviderWithApp:app];
  } else {
    FIRLogWarning(kFIRLoggerAppCheck, kFIRLoggerAppCheckMessageCodeDeviceCheckProviderUnavailable,
                  @"DeviceCheck is not supported on this device/OS version. "
                  @"App Check enforcement will fail.");
    return nil;
  }

#endif  // TARGET_OS_SIMULATOR
}

@end
