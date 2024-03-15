/*
 * Copyright 2024 Google LLC
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
 * The source the snapshot listener retrieves data from.
 */
typedef NS_ENUM(NSUInteger, FIRListenSource) {
  /**
   * The default behavior. The listener attempts to return initial snapshot from cache and retrieve
   * up-to-date snapshots from the Firestore server. Snapshot events will be triggered on local
   * mutations and server-side updates.
   */
  FIRListenSourceDefault,
  /**
   * The listener retrieves data and listens to updates from the local Firestore cache without
   * attempting to send the query to the server. If some documents gets updated as a result from
   * other queries, they will be picked up by listeners using the cache.
   *
   * Note that the data might be stale if the cache hasn't synchronized with recent server-side
   * changes.
   */
  FIRListenSourceCache
} NS_SWIFT_NAME(ListenSource);

/**
 * Options to configure the behavior of `Firestore.addSnapshotListenerWithOptions()`. Instances
 * of this class control settings like whether metadata-only changes trigger events and the
 * preferred data source.
 */
NS_SWIFT_NAME(SnapshotListenOptions)
@interface FIRSnapshotListenOptions : NSObject

/** The source the snapshot listener retrieves data from. */
@property(nonatomic, readonly) FIRListenSource source;
/** Indicates whether metadata-only changes should trigger snapshot events. */
@property(nonatomic, readonly) BOOL includeMetadataChanges;

/**
 * Creates and returns a new `SnapshotListenOptions` object with all properties initialized to their
 * default values.
 *
 * @return The created `SnapshotListenOptions` object.
 */
- (instancetype)init NS_DESIGNATED_INITIALIZER;

/**
 * Creates and returns a new `SnapshotListenOptions` object with with all properties of the current
 * `SnapshotListenOptions` object plus the new property specifying whether metadata-only changes
 * should trigger snapshot events
 *
 * @return The created `SnapshotListenOptions` object.
 */
- (FIRSnapshotListenOptions *)optionsWithIncludeMetadataChanges:(BOOL)includeMetadataChanges;

/**
 * Creates and returns a new `SnapshotListenOptions` object with with all properties of the current
 * `SnapshotListenOptions` object plus the new property specifying the source that the snapshot
 * listener listens to.
 *
 * @return The created `SnapshotListenOptions` object.
 */
- (FIRSnapshotListenOptions *)optionsWithSource:(FIRListenSource)source;

@end

NS_ASSUME_NONNULL_END
