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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol FIRLocalCacheSettings;

/** Used to set on-disk cache size to unlimited. Garbage collection will not run. */
FOUNDATION_EXTERN const int64_t
    kFIRFirestoreCacheSizeUnlimited NS_SWIFT_NAME(FirestoreCacheSizeUnlimited);

/** Settings used to configure a `Firestore` instance. */
NS_SWIFT_NAME(FirestoreSettings)
@interface FIRFirestoreSettings : NSObject <NSCopying>

/**
 * Creates and returns an empty `FirestoreSettings` object.
 *
 * @return The created `FirestoreSettings` object.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/** The hostname to connect to. */
@property(nonatomic, copy) NSString* host;

/** Whether to use SSL when connecting. */
@property(nonatomic, getter=isSSLEnabled) BOOL sslEnabled;

/**
 * A dispatch queue to be used to execute all completion handlers and event handlers. By default,
 * the main queue is used.
 */
@property(nonatomic, strong) dispatch_queue_t dispatchQueue;

/**
 * NOTE: This field will be deprecated in a future major release. Use the `cacheSettings` field
 * instead to specify cache type, and other cache configurations.
 *
 * Set to false to disable local persistent storage.
 */
@property(nonatomic, getter=isPersistenceEnabled) BOOL persistenceEnabled DEPRECATED_MSG_ATTRIBUTE(
    "This field is deprecated. Use `cacheSettings` instead.");

/**
 * NOTE: This field will be deprecated in a future major release. Use the `cacheSettings` field
 * instead to specify cache size, and other cache configurations.
 *
 * Sets the cache size threshold above which the SDK will attempt to collect least-recently-used
 * documents. The size is not a guarantee that the cache will stay below that size, only that if
 * the cache exceeds the given size, cleanup will be attempted. Cannot be set lower than 1MB.
 *
 * Set to `FirestoreCacheSizeUnlimited` to disable garbage collection entirely.
 */
@property(nonatomic, assign) int64_t cacheSizeBytes DEPRECATED_MSG_ATTRIBUTE(
    "This field is deprecated. Use `cacheSettings` instead.");

/**
 * Specifies the cache used by the SDK. Available options are `PersistentCacheSettings`
 * and `MemoryCacheSettings`, each with different configuration options.
 *
 * When unspecified, `PersistentCacheSettings` will be used by default.
 *
 * NOTE: setting this field and `cacheSizeBytes` or `persistenceEnabled` at the same time will throw
 * an exception during SDK initialization. Instead, use the configuration in
 * the `PersistentCacheSettings` object to specify the cache size.
 */
@property(nonatomic, strong) id<FIRLocalCacheSettings, NSObject> cacheSettings;

@end

NS_ASSUME_NONNULL_END
