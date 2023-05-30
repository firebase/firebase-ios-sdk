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

#import "GACAppCheckAvailability.h"
#import "GACAppCheckProvider.h"

#if GAC_DEVICE_CHECK_SUPPORTED_TARGETS

@protocol GACDeviceCheckAPIServiceProtocol;
@protocol GACDeviceCheckTokenGenerator;

NS_ASSUME_NONNULL_BEGIN

/// Firebase App Check provider that verifies app integrity using the
/// [DeviceCheck](https://developer.apple.com/documentation/devicecheck) API.
/// This class is available on all platforms for select OS versions. See
/// https://firebase.google.com/docs/ios/learn-more for more details.
GAC_DEVICE_CHECK_PROVIDER_AVAILABILITY
NS_SWIFT_NAME(InternalDeviceCheckProvider)
@interface GACDeviceCheckProvider : NSObject <GACAppCheckProvider>

- (instancetype)init NS_UNAVAILABLE;

/// The default initializer.
/// @param storageID A unique identifier to differentiate storage keys corresponding to the same
/// `resourceName`; may be a Firebase App Name or an SDK name.
/// @param resourceName The name of the resource protected by App Check; for a Firebase App this is
/// "projects/{project_id}/apps/{app_id}".
/// @param APIKey The Google Cloud Platform API key, if needed, or nil.
/// @param requestHooks Hooks that will be invoked on requests through this service.
/// @return An instance of `DeviceCheckProvider` .
- (instancetype)initWithStorageID:(NSString *)storageID
                     resourceName:(NSString *)resourceName
                           APIKey:(nullable NSString *)APIKey
                     requestHooks:(nullable NSArray<GACAppCheckAPIRequestHook> *)requestHooks;

@end

NS_ASSUME_NONNULL_END

#endif  // GAC_DEVICE_CHECK_SUPPORTED_TARGETS
