/*
 * Copyright 2017 Google LLC
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

// TODO(wuandy): Delete this once isPersistenceEnabled and cacheSizeBytes are removed.
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

#import "FIRFirestoreSettings.h"
#import <Foundation/NSObject.h>
#import "FIRLocalCacheSettings+Internal.h"
#include "Firestore/Source/Public/FirebaseFirestore/FIRLocalCacheSettings.h"

#include "Firestore/core/src/api/settings.h"
#include "Firestore/core/src/util/exception.h"
#include "Firestore/core/src/util/string_apple.h"

NS_ASSUME_NONNULL_BEGIN

namespace api = firebase::firestore::api;
using api::Settings;
using firebase::firestore::util::MakeString;
using firebase::firestore::util::ThrowInvalidArgument;

// Public constant
extern "C" const int64_t kFIRFirestoreCacheSizeUnlimited = Settings::CacheSizeUnlimited;

@implementation FIRFirestoreSettings

- (instancetype)init {
  if (self = [super init]) {
    _host = [NSString stringWithUTF8String:Settings::DefaultHost];
    _sslEnabled = Settings::DefaultSslEnabled;
    _dispatchQueue = dispatch_get_main_queue();
    _persistenceEnabled = Settings::DefaultPersistenceEnabled;
    _cacheSizeBytes = Settings::DefaultCacheSizeBytes;
  }
  return self;
}

- (BOOL)isEqual:(id)other {
  if (self == other) {
    return YES;
  } else if (![other isKindOfClass:[FIRFirestoreSettings class]]) {
    return NO;
  }

  FIRFirestoreSettings *otherSettings = (FIRFirestoreSettings *)other;
  BOOL equal = [self.host isEqual:otherSettings.host] &&
               self.isSSLEnabled == otherSettings.isSSLEnabled &&
               self.dispatchQueue == otherSettings.dispatchQueue &&
               self.isPersistenceEnabled == otherSettings.isPersistenceEnabled &&
               self.cacheSizeBytes == otherSettings.cacheSizeBytes;

  if (equal && self.cacheSettings != nil && otherSettings.cacheSettings != nil) {
    equal = [self.cacheSettings isEqual:otherSettings];
  } else if (equal) {
    equal = (self.cacheSettings == otherSettings.cacheSettings);
  }

  return equal;
}

- (NSUInteger)hash {
  NSUInteger result = [self.host hash];
  result = 31 * result + (self.isSSLEnabled ? 1231 : 1237);
  // Ignore the dispatchQueue to avoid having to deal with sizeof(dispatch_queue_t).
  result = 31 * result + (self.isPersistenceEnabled ? 1231 : 1237);
  result = 31 * result + (NSUInteger)self.cacheSizeBytes;

  if ([_cacheSettings isKindOfClass:[FIRPersistentCacheSettings class]]) {
    FIRPersistentCacheSettings *casted = (FIRPersistentCacheSettings *)_cacheSettings;
    result = 31 * result + casted.internalSettings.Hash();
  } else if ([_cacheSettings isKindOfClass:[FIRMemoryCacheSettings class]]) {
    FIRMemoryCacheSettings *casted = (FIRMemoryCacheSettings *)_cacheSettings;
    result = 31 * result + casted.internalSettings.Hash();
  }

  return result;
}

- (id)copyWithZone:(__unused NSZone *_Nullable)zone {
  FIRFirestoreSettings *copy = [[FIRFirestoreSettings alloc] init];
  copy.host = _host;
  copy.sslEnabled = _sslEnabled;
  copy.dispatchQueue = _dispatchQueue;
  copy.persistenceEnabled = _persistenceEnabled;
  copy.cacheSizeBytes = _cacheSizeBytes;
  copy.cacheSettings = _cacheSettings;
  return copy;
}

- (void)setHost:(NSString *)host {
  if (!host) {
    ThrowInvalidArgument("Host setting may not be nil. You should generally just use the default "
                         "value (which is %s)",
                         Settings::DefaultHost);
  }
  _host = [host mutableCopy];
}

- (void)setDispatchQueue:(dispatch_queue_t)dispatchQueue {
  if (!dispatchQueue) {
    ThrowInvalidArgument(
        "Dispatch queue setting may not be nil. Create a new dispatch queue with "
        "dispatch_queue_create(\"com.example.MyQueue\", NULL) or just use the default (which is "
        "the main queue, returned from dispatch_get_main_queue())");
  }
  _dispatchQueue = dispatchQueue;
}

- (void)setCacheSizeBytes:(int64_t)cacheSizeBytes {
  if (cacheSizeBytes != kFIRFirestoreCacheSizeUnlimited &&
      cacheSizeBytes < Settings::MinimumCacheSizeBytes) {
    ThrowInvalidArgument("Cache size must be set to at least %s bytes",
                         Settings::MinimumCacheSizeBytes);
  }
  _cacheSizeBytes = cacheSizeBytes;
}

- (void)setCacheSettings:(id<FIRLocalCacheSettings, NSObject>)cacheSettings {
  _cacheSettings = cacheSettings;
}

- (BOOL)isUsingDefaultHost {
  NSString *defaultHost = [NSString stringWithUTF8String:Settings::DefaultHost];
  return [self.host isEqualToString:defaultHost];
}

- (Settings)internalSettings {
  Settings settings;
  settings.set_host(MakeString(_host));
  settings.set_ssl_enabled(_sslEnabled);
  settings.set_persistence_enabled(_persistenceEnabled);
  settings.set_cache_size_bytes(_cacheSizeBytes);

  if ([_cacheSettings isKindOfClass:[FIRPersistentCacheSettings class]]) {
    FIRPersistentCacheSettings *casted = (FIRPersistentCacheSettings *)_cacheSettings;
    settings.set_local_cache_settings(casted.internalSettings);
  } else if ([_cacheSettings isKindOfClass:[FIRMemoryCacheSettings class]]) {
    FIRMemoryCacheSettings *casted = (FIRMemoryCacheSettings *)_cacheSettings;
    settings.set_local_cache_settings(casted.internalSettings);
  }

  return settings;
}

@end

NS_ASSUME_NONNULL_END
