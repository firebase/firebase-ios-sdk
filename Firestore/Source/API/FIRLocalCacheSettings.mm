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

NS_ASSUME_NONNULL_BEGIN

namespace api = firebase::firestore::api;
using api::MemoryCacheSettings;
using api::MemoryEagerGcSettings;
using api::MemoryLruGcSettings;
using api::PersistentCacheSettings;
using api::Settings;
using firebase::firestore::util::ThrowInvalidArgument;

@implementation FIRPersistentCacheSettings {
  PersistentCacheSettings _internalSettings;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FIRPersistentCacheSettings class]]) {
    return NO;
  }

  FIRPersistentCacheSettings *otherSettings = (FIRPersistentCacheSettings *)other;
  return _internalSettings == otherSettings.internalSettings;
}

- (NSUInteger)hash {
  return _internalSettings.Hash();
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
  if (size.longLongValue != Settings::CacheSizeUnlimited &&
      size.longLongValue < Settings::MinimumCacheSizeBytes) {
    ThrowInvalidArgument("Cache size must be set to at least %s bytes",
                         Settings::MinimumCacheSizeBytes);
  }

  self.internalSettings = PersistentCacheSettings{}.WithSizeBytes(size.longLongValue);
  return self;
}

@end

@implementation FIRMemoryEagerGCSettings {
  MemoryEagerGcSettings _internalSettings;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FIRMemoryEagerGCSettings class]]) {
    return NO;
  }

  FIRMemoryEagerGCSettings *otherSettings = (FIRMemoryEagerGCSettings *)other;
  return _internalSettings == otherSettings.internalSettings;
}

- (NSUInteger)hash {
  return _internalSettings.Hash();
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  FIRMemoryEagerGCSettings *copy = [[FIRMemoryEagerGCSettings alloc] init];
  copy.internalSettings = self.internalSettings;
  return copy;
}

- (void)setInternalSettings:(const MemoryEagerGcSettings &)settings {
  _internalSettings = settings;
}

- (const MemoryEagerGcSettings &)internalSettings {
  return _internalSettings;
}

- (instancetype)init {
  if (self = [super init]) {
    self.internalSettings = MemoryEagerGcSettings{};
  }
  return self;
}

@end

@implementation FIRMemoryLRUGCSettings {
  MemoryLruGcSettings _internalSettings;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FIRMemoryLRUGCSettings class]]) {
    return NO;
  }

  FIRMemoryLRUGCSettings *otherSettings = (FIRMemoryLRUGCSettings *)other;
  return _internalSettings == otherSettings.internalSettings;
}

- (NSUInteger)hash {
  return _internalSettings.Hash();
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  FIRMemoryLRUGCSettings *copy = [[FIRMemoryLRUGCSettings alloc] init];
  copy.internalSettings = self.internalSettings;
  return copy;
}

- (void)setInternalSettings:(const MemoryLruGcSettings &)settings {
  _internalSettings = settings;
}

- (const MemoryLruGcSettings &)internalSettings {
  return _internalSettings;
}

- (instancetype)init {
  if (self = [super init]) {
    self.internalSettings = MemoryLruGcSettings{};
  }
  return self;
}

- (instancetype)initWithSizeBytes:(NSNumber *)size {
  if (self = [super init]) {
    self.internalSettings = MemoryLruGcSettings{}.WithSizeBytes(size.longLongValue);
  }
  return self;
}

@end

@implementation FIRMemoryCacheSettings {
  MemoryCacheSettings _internalSettings;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FIRMemoryCacheSettings class]]) {
    return NO;
  }

  FIRMemoryCacheSettings *otherSettings = (FIRMemoryCacheSettings *)other;
  return _internalSettings == otherSettings.internalSettings;
}

- (NSUInteger)hash {
  return _internalSettings.Hash();
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
  if (self = [super init]) {
    self.internalSettings = MemoryCacheSettings{};
  }
  return self;
}

- (instancetype)initWithGarbageCollectorSettings:
    (id<FIRMemoryGarbageCollectorSettings, NSObject>)settings {
  if (self = [super init]) {
    if ([settings isKindOfClass:[FIRMemoryEagerGCSettings class]]) {
      FIRMemoryEagerGCSettings *casted = (FIRMemoryEagerGCSettings *)settings;
      self.internalSettings =
          MemoryCacheSettings{}.WithMemoryGarbageCollectorSettings(casted.internalSettings);
    } else if ([settings isKindOfClass:[FIRMemoryLRUGCSettings class]]) {
      FIRMemoryLRUGCSettings *casted = (FIRMemoryLRUGCSettings *)settings;
      self.internalSettings =
          MemoryCacheSettings{}.WithMemoryGarbageCollectorSettings(casted.internalSettings);
    }
  }

  return self;
}

@end

NS_ASSUME_NONNULL_END
