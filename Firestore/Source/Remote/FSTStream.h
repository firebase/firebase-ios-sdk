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

#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

@class FSTMutationResult;
@class FSTWatchChange;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTWatchStreamDelegate

/** A protocol defining the events that can be emitted by the FSTWatchStream. */
@protocol FSTWatchStreamDelegate <NSObject>

/** Called by the FSTWatchStream when it is ready to accept outbound request messages. */
- (void)watchStreamDidOpen;

/**
 * Called by the FSTWatchStream with changes and the snapshot versions included in in the
 * WatchChange responses sent back by the server.
 */
- (void)watchStreamDidChange:(FSTWatchChange *)change
             snapshotVersion:(const firebase::firestore::model::SnapshotVersion &)snapshotVersion;

/**
 * Called by the FSTWatchStream when the underlying streaming RPC is interrupted for whatever
 * reason, usually because of an error, but possibly due to an idle timeout. The error passed to
 * this method may be nil, in which case the stream was closed without attributable fault.
 *
 * NOTE: This will not be called after `stop` is called on the stream. See "Starting and Stopping"
 * on FSTStream for details.
 */
- (void)watchStreamWasInterruptedWithError:(nullable NSError *)error;

@end

#pragma mark - FSTWriteStreamDelegate

@protocol FSTWriteStreamDelegate <NSObject>

/** Called by the FSTWriteStream when it is ready to accept outbound request messages. */
- (void)writeStreamDidOpen;

/**
 * Called by the FSTWriteStream upon a successful handshake response from the server, which is the
 * receiver's cue to send any pending writes.
 */
- (void)writeStreamDidCompleteHandshake;

/**
 * Called by the FSTWriteStream upon receiving a StreamingWriteResponse from the server that
 * contains mutation results.
 */
- (void)writeStreamDidReceiveResponseWithVersion:
            (const firebase::firestore::model::SnapshotVersion &)commitVersion
                                 mutationResults:(NSArray<FSTMutationResult *> *)results;

/**
 * Called when the FSTWriteStream's underlying RPC is interrupted for whatever reason, usually
 * because of an error, but possibly due to an idle timeout. The error passed to this method may be
 * nil, in which case the stream was closed without attributable fault.
 *
 * NOTE: This will not be called after `stop` is called on the stream. See "Starting and Stopping"
 * on FSTStream for details.
 */
- (void)writeStreamWasInterruptedWithError:(nullable NSError *)error;

@end

NS_ASSUME_NONNULL_END
