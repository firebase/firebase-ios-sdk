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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Marker protocol implemented by all supported cache settings.
 *
 * The two cache types supported are `PersistentCacheSettings` and `MemoryCacheSettings`. Custom
 * implementation is not supported.
 */
NS_SWIFT_NAME(LocalCacheSettings)
@protocol FIRLocalCacheSettings
@end

/**
 * Configures the SDK to use a persistent cache. Firestore documents and mutations are persisted
 * across App restart.
 *
 * This is the default cache type unless explicitly specified otherwise.
 *
 * To use, create an instance using one of the initializers, then set the instance to
 * `FirestoreSettings.cacheSettings`, and use `FirestoreSettings` instance to configure Firestore
 * SDK.
 */
NS_SWIFT_NAME(PersistentCacheSettings)
@interface FIRPersistentCacheSettings : NSObject <NSCopying, FIRLocalCacheSettings>

/**
 * Creates `PersistentCacheSettings` with default cache size: 100MB.
 *
 * The cache size is not a hard limit, but a target for the SDK's gabarge collector to work towards.
 */
- (instancetype)init;

/**
 * Creates `PersistentCacheSettings` with a custom cache size in bytes.
 *
 * The cache size is not a hard limit, but a target for the SDK's gabarge collector to work towards.
 */
- (instancetype)initWithSizeBytes:(NSNumber *)size;

@end

/**
 * Marker protocol implemented by all supported garbage collector settings.
 *
 * The two cache types supported are `MemoryEagerGCSettings` and `MemoryLRUGCSettings`. Custom
 * implementation is not supported.
 */
NS_SWIFT_NAME(MemoryGarbageCollectorSettings)
@protocol FIRMemoryGarbageCollectorSettings
@end

/**
 * Configures the SDK to use an eager garbage collector for memory cache.
 *
 * Once configured, the SDK will remove any Firestore documents from memory as soon as they are not
 * used by any active queries.
 *
 * To use, create an instance using the initializer, then initialize
 * `MemoryCacheSettings` with this instance. This is the default garbage collector, so alternatively
 * you can use the default initializer of `MemoryCacheSettings`.
 */
NS_SWIFT_NAME(MemoryEagerGCSetting)
@interface FIRMemoryEagerGCSettings : NSObject <NSCopying, FIRMemoryGarbageCollectorSettings>

/**
 * Creates an instance of `MemoryEagerGCSettings`.
 */
- (instancetype)init;

@end

/**
 * Configures the SDK to use a least-recently-used garbage collector for memory cache.
 *
 * Once configured, the SDK will attempt to remove documents that are least recently used in
 * batches, if the current cache size is larger than the given target cache size. Default cache size
 * is 100MB.
 *
 * To use, create an instance using one of the initializers, then initialize
 * `MemoryCacheSettings` with this instance.
 */
NS_SWIFT_NAME(MemoryLRUGCSettings)
@interface FIRMemoryLRUGCSettings : NSObject <NSCopying, FIRMemoryGarbageCollectorSettings>

/**
 * Creates an instance of `FIRMemoryLRUGCSettings`, with default target cache size 100MB. The SDK
 * will run garbage collection if the current cache size is larger than 100MB.
 */
- (instancetype)init;

/**
 * Creates an instance of `FIRMemoryLRUGCSettings`, with a custom target cache size. The SDK will
 * run garbage collection if the current cache size is larger than the given size.
 */
- (instancetype)initWithSizeBytes:(NSNumber *)size;

@end

/**
 * Configures the SDK to use a memory cache. Firestore documents and mutations are NOT persisted
 * across App restart.
 *
 * To use, create an instance using one of the initializer, then set the instance to
 * `FirestoreSettings.cacheSettings`, and use `FirestoreSettings` instance to configure Firestore
 * SDK.
 */
NS_SWIFT_NAME(MemoryCacheSettings)
@interface FIRMemoryCacheSettings : NSObject <NSCopying, FIRLocalCacheSettings>

/**
 * Creates an instance of `MemoryCacheSettings`.
 */
- (instancetype)init;

/**
 * Creates an instance of `MemoryCacheSettings` with given `MemoryGarbageCollectorSettings` to
 * custom the gabarge collector.
 */
- (instancetype)initWithGarbageCollectorSettings:
    (id<FIRMemoryGarbageCollectorSettings, NSObject>)settings;

@end

NS_ASSUME_NONNULL_END
