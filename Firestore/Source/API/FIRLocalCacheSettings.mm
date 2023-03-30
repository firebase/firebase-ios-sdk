/*
 * Copyright 2023 Google LLC
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

#include "FIRLocalCacheSettings.h"
#include <memory>
#import "FIRLocalCacheSettings+Internal.h"
#include "absl/memory/memory.h"

#include "Firestore/core/src/api/settings.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/string_apple.h"

NS_ASSUME_NONNULL_BEGIN

namespace api = firebase::firestore::api;
using api::MemoryCacheSettings;
using api::PersistentCacheSettings;

@implementation FIRLocalCacheSettings

- (instancetype)initWithSize:(NSNumber *)s {
  return self;
}

@end

@implementation FIRPersistentCacheSettings {
  PersistentCacheSettings _internalSettings;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  FIRPersistentCacheSettings *copy = [[FIRPersistentCacheSettings alloc] init];
  copy.internalSettings = self.internalSettings;
  return copy;
}

- (void)setInternalSettings:(const PersistentCacheSettings &)settings {
  _internalSettings = settings;
}

- (const PersistentCacheSettings &)internalSettings {
  return _internalSettings;
}

- (instancetype)init {
  self = [super init];
  self.internalSettings = PersistentCacheSettings{};
  return self;
}

- (instancetype)initWithSizeBytes:(NSNumber *)size {
  self = [super init];
  self.internalSettings = PersistentCacheSettings{}.WithSizeBytes(size.longLongValue);
  return self;
}

@end

@implementation FIRMemoryCacheSettings {
  MemoryCacheSettings _internalSettings;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  FIRMemoryCacheSettings *copy = [[FIRMemoryCacheSettings alloc] init];
  copy.internalSettings = self.internalSettings;
  return copy;
}

- (void)setInternalSettings:(const MemoryCacheSettings &)settings {
  _internalSettings = settings;
}

- (const MemoryCacheSettings &)internalSettings {
  return _internalSettings;
}

- (instancetype)init {
  self = [super init];
  self.internalSettings = MemoryCacheSettings{};
  return self;
}

@end

NS_ASSUME_NONNULL_END
