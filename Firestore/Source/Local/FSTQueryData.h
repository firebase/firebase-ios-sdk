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

#include "Firestore/core/src/firebase/firestore/core/query.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"
#include "Firestore/core/src/firebase/firestore/model/types.h"

namespace core = firebase::firestore::core;
namespace model = firebase::firestore::model;

NS_ASSUME_NONNULL_BEGIN

/** An enumeration of the different purposes we have for queries. */
typedef NS_ENUM(NSInteger, FSTQueryPurpose) {
  /** A regular, normal query. */
  FSTQueryPurposeListen,

  /** The query was used to refill a query after an existence filter mismatch. */
  FSTQueryPurposeExistenceFilterMismatch,

  /** The query was used to resolve a limbo document. */
  FSTQueryPurposeLimboResolution,
};

/** An immutable set of metadata that the store will need to keep track of for each query. */
@interface FSTQueryData : NSObject

- (instancetype)initWithQuery:(core::Query)query
                     targetID:(model::TargetId)targetID
         listenSequenceNumber:(model::ListenSequenceNumber)sequenceNumber
                      purpose:(FSTQueryPurpose)purpose
              snapshotVersion:(model::SnapshotVersion)snapshotVersion
                  resumeToken:(NSData *)resumeToken NS_DESIGNATED_INITIALIZER;

/** Convenience initializer for use when creating an FSTQueryData for the first time. */
- (instancetype)initWithQuery:(core::Query)query
                     targetID:(model::TargetId)targetID
         listenSequenceNumber:(model::ListenSequenceNumber)sequenceNumber
                      purpose:(FSTQueryPurpose)purpose;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates a new query data instance with an updated snapshot version, resume token, and sequence
 * number.
 */
- (instancetype)queryDataByReplacingSnapshotVersion:(model::SnapshotVersion)snapshotVersion
                                        resumeToken:(NSData *)resumeToken
                                     sequenceNumber:(model::ListenSequenceNumber)sequenceNumber;

/** The latest snapshot version seen for this target. */
- (const model::SnapshotVersion &)snapshotVersion;

/** The query being listened to. */
- (const core::Query &)query;

/**
 * The targetID to which the query corresponds, assigned by the FSTLocalStore for user queries or
 * the FSTSyncEngine for limbo queries.
 */
@property(nonatomic, assign, readonly) model::TargetId targetID;

@property(nonatomic, assign, readonly) model::ListenSequenceNumber sequenceNumber;

/** The purpose of the query. */
@property(nonatomic, assign, readonly) FSTQueryPurpose purpose;

/**
 * An opaque, server-assigned token that allows watching a query to be resumed after disconnecting
 * without retransmitting all the data that matches the query. The resume token essentially
 * identifies a point in time from which the server should resume sending results.
 */
@property(nonatomic, copy, readonly) NSData *resumeToken;

@end

NS_ASSUME_NONNULL_END
