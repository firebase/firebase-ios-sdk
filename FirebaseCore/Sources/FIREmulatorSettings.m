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

/** :nodoc: */
NSString *const FIREmulatorServiceDatabase = @"FIREmulatorServiceDatabase";

/** :nodoc: */
NSString *const FIREmulatorServiceFirestore = @"FIREmulatorServiceFirestore";

/** :nodoc: */
NSString *const FIREmulatorServiceAuth = @"FIREmulatorServiceAuth";

/** :nodoc: */
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
  NSAssert(settings.count > 0,
           @"Creating emulator settings requires non-empty service settings list.");
  self = [super init];
  if (self != nil) {
    _settings = [settings copy];
  }
  return self;
}

- (instancetype)initWithServiceSettings:(FIREmulatorServiceSettings *)settings
                             forService:(FIREmulatorService)service {
  NSAssert(settings != nil);
  NSAssert(service != nil);
  NSDictionary *settings = @{service : settings};
  return [self initWithSettings:settings];
}

- (instancetype)copyWithZone:(NSZone *)zone {
  return self;  // immutable, so return self
}

- (FIREmulatorSettings *)settingsForService:(FIREmulatorService)service {
  return self.settings[service];
}

@end
