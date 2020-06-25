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

#import "FirebaseCore/Sources/Public/FIREmulatorSettings.h"

NSString *const FIREmulatorServiceDatabase = @"FIREmulatorServiceDatabase";
NSString *const FIREmulatorServiceFirestore = @"FIREmulatorServiceFirestore";
NSString *const FIREmulatorServiceAuth = @"FIREmulatorServiceAuth";
NSString *const FIREmulatorServiceFunctions = @"FIREmulatorServiceFunctions";

@implementation FIREmulatorServiceSettings

- (instancetype)init {
  NSAssert(NO, @"The default initializer is unavailable. Call the designated initializer instead.");
}

- (instancetype)initWithHost:(NSString *)host port:(NSInteger)port {
  NSAssert(host != nil, @"A nonnull host is required");
  self = [super init];
  if (self != nil) {
    _host = [host copy];
    _port = port;
  }
  return self;
}

- (instancetype)copyWithZone:(NSZone *)zone {
  return self;  // instances are immutable, so return self
}

@end

@interface FIREmulatorSettings ()

@property(nonatomic, copy, nonnull)
    NSDictionary<FIREmulatorService, FIREmulatorServiceSettings *> *settings;

@end

@implementation FIREmulatorSettings

- (instancetype)init {
  NSAssert(NO, @"The default initializer is unavailable. Call the designated initializer instead.");
}

- (instancetype)initWithSettings:
    (NSDictionary<FIREmulatorService, FIREmulatorServiceSettings *> *)settings {
  NSAssert(settings != nil,
           @"Creating emulator settings requires nonnull service settings list.");
  self = [super init];
  if (self != nil) {
    _settings = [settings copy];
  }
  return self;
}

- (instancetype)initWithServiceSettings:(FIREmulatorServiceSettings *)serviceSettings
                             forService:(FIREmulatorService)service {
  NSAssert(serviceSettings != nil, @"Service settings must be nonnull");
  NSAssert(service != nil, @"Service name must be nonnull");
  NSDictionary *settings = @{service : serviceSettings};
  return [self initWithSettings:settings];
}

- (instancetype)settingsByCombiningSettings:(FIREmulatorSettings *)settings {
  NSMutableDictionary *mutableSettings = [self.settings mutableCopy];
  NSDictionary *otherSettings = settings->settings;
  for (FIREmulatorService key in otherSettings.allKeys) {
    mutableSettings[key] = otherSettings[key];
  }
  return [[FIREmulatorSettings alloc] initWithSettings:mutableSettings];
}

- (instancetype)settingsByRemovingSettingsForService:(FIREmulatorService)service {
  NSMutableDictionary *mutableSettings = [self.settings mutableCopy];
  [mutableSettings removeObjectForKey:service];
  return [[FIREmulatorSettings alloc] initWithSettings:mutableSettings];
}

- (instancetype)settingsByAddingSettings:(FIREmulatorServiceSettings *)settings 
                              forService:(FIREmulatorService)service {
  NSMutableDictionary *mutableSettings = [self.settings mutableCopy];
  [mutableSettings addObject:settings];
  return [[FIREmulatorSettings alloc] initWithSettings:mutableSettings];
}

- (NSDictionary *)getAllServiceSettings {
  return [self.settings copy];
}

- (instancetype)copyWithZone:(NSZone *)zone {
  return self;  // immutable, so return self
}

- (FIREmulatorServiceSettings *)settingsForService:(FIREmulatorService)service {
  return self.settings[service];
}

@end
