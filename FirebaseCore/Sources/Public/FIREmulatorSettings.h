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

NS_ASSUME_NONNULL_BEGIN

/// A string constant representing a Firebase service with an emulator available.
typedef NSString *FIREmulatorService NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(EmulatorSettings);

/** :nodoc: */
NSString *const FIREmulatorServiceDatabase;

/** :nodoc: */
NSString *const FIREmulatorServiceFirestore;

/** :nodoc: */
NSString *const FIREmulatorServiceAuth;

/** :nodoc: */
NSString *const FIREmulatorServiceFunctions;

/// A class representing the connection settings for an emulated Firebase service.
NS_SWIFT_NAME(EmulatorServiceSettings)
@interface FIREmulatorServiceSettings : NSObject <NSCopying>

/// The host of the emulated service, "localhost" for example.
@property(nonatomic, readonly) NSString *host;

/// The port number of the emulated service.
@property(nonatomic, readonly) NSInteger port;

/// Creates a new instance with the specified host name and port number.
- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port NS_DESIGNATED_INITIALIZER;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

/// A class representing per-app settings for emulated Firebase services.
NS_SWIFT_NAME(EmulatorSettings)
@interface FIREmulatorSettings : NSObject <NSCopying>

/// Initializes an app-level settings instance with the given emulator service settings.
- (instancetype)initWithServiceSettings:(FIREmulatorServiceSettings *)settings
                             forService:(FIREmulatorService *)service;

/// Initializes an app-level settings instance with all of the provided settings.
/// The provided settings dictionary must not be empty.
- (instancetype)initWithSettings:
    (NSDictionary<FIREmulatorService *, FIREmulatorServiceSettings *> *)settings
    NS_DESIGNATED_INITIALIZER;

/// Returns the service-level settings object for a given emulated service, if it exists.
- (FIREmulatorSettings *_Nullable)settingsForService:(FIREmulatorService *)service;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
