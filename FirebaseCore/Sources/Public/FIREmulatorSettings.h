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
FIREmulatorService const FIREmulatorServiceDatabase;

/** :nodoc: */
FIREmulatorService const FIREmulatorServiceFirestore;

/** :nodoc: */
FIREmulatorService const FIREmulatorServiceAuth;

/** :nodoc: */
FIREmulatorService const FIREmulatorServiceFunctions;

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

/// Returns a dictionary containing all service settings.
@property (nonatomic, readonly, copy) 
        NSDictionary<FIREmulatorService, FIREmulatorServiceSettings *> *allServiceSettings;

/// Initializes an app-level settings instance with the given emulator service settings.
- (instancetype)initWithServiceSettings:(FIREmulatorServiceSettings *)settings
                             forService:(FIREmulatorService)service;

/// Initializes an app-level settings instance with all of the provided settings.
- (instancetype)initWithSettings:
    (NSDictionary<FIREmulatorService, FIREmulatorServiceSettings *> *)settings
    NS_DESIGNATED_INITIALIZER;

/// Returns a new settings object that is the union of the receiver and the settings argument.
/// Settings in the settings argument overwrite pre-existing settings in the receiver.
- (instancetype)settingsByCombiningSettings:(FIREmulatorSettings *)settings;

/// Returns a new settings object that is the result of removing the settings for a given
/// service.
- (instancetype)settingsByRemovingSettingsForService:(FIREmulatorService)service;

/// Returns a new settings object that is the result of adding new settings for a given
/// service. Overwrites a pre-existing settings entry for the given key, if it exists.
- (instancetype)settingsByAddingSettings:(FIREmulatorServiceSettings *)settings 
                              forService:(FIREmulatorService)service

/// Returns a new settings object that is the result of adding new settings for a given
/// service. Overwrites a pre-existing settings entry for the given key, if it exists.
- (instancetype)settingsByAddingSettingsWithHost:(NSString *)host
                                            port:(NSInteger)port 
                                      forService:(FIREmulatorService)service;

/// Returns the service-level settings object for a given emulated service, if it exists.
- (FIREmulatorServiceSettings *_Nullable)settingsForService:(FIREmulatorService)service;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
