/*
 * Copyright 2017 Google
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
 * An options object that configures the behavior of get*() calls, such as
 * getDocument() in `FIRDocumentReference`. By providing the `FIRGetOptions`
 * objects returned by `fromServer:`, `fromCache:`, or `fromDefault:`, the get*
 * methods can be configured to fetch results only from the server, only from
 * the local cache, or attempt the server and fall back to the cache,
 * respectively.
 */
NS_SWIFT_NAME(GetOptions)
@interface FIRGetOptions : NSObject

- (id)init NS_UNAVAILABLE;

/**
 * The default behavior, if online, is to try to give a consistent
 * (server-retrieved) snapshot, or else revert to the cache to provide a value.
 *
 * @return The created `FIRGetOptions` object
 */
+ (instancetype)fromDefault;

/**
 * Changes the behavior of the various get calls to always give consistent
 * (server-retrieved) snapshots. If the device is offline or the RPC fails, we
 * will return an error. The cache will be always updated if the RPC succeeded.
 *
 * @return The created `FIRGetOptions` object
 */
+ (instancetype)fromServer;

/**
 * Changes the behavior of the various get calls to always give a cached
 * version, no matter the connection state. For queries this could be
 * potentially an empty snapshot. For a single document, the get will fail if
 * the document doesn't exist.
 *
 * @return The created `FIRGetOptions` object
 */
+ (instancetype)fromCache;

/** Describes whether we should get from server or cache. */
typedef NS_ENUM(NSUInteger, FSTGetLocation) {
  FSTGetFromDefault,
  FSTGetFromServer,
  FSTGetFromCache
};

/** Where get calls should get their data from. */
@property(nonatomic, readonly, getter=getGetLocation) FSTGetLocation getLocation;

@end

NS_ASSUME_NONNULL_END
