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

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/snapshot_version.h"

@class FSTDispatchQueue;
@class FSTMutation;
@class FSTMutationResult;
@class FSTQueryData;
@class FSTSerializerBeta;
@class FSTWatchChange;
@class FSTWatchStream;
@class FSTWriteStream;
@class GRPCCall;
@class GRXWriter;

@protocol FSTWatchStreamDelegate;
@protocol FSTWriteStreamDelegate;

NS_ASSUME_NONNULL_BEGIN

/**
 * An FSTStream is an abstract base class that represents a restartable streaming RPC to the
 * Firestore backend. It's built on top of GRPC's own support for streaming RPCs, and adds several
 * critical features for our clients:
 *
 *   - Restarting a stream is allowed (after failure)
 *   - Exponential backoff on failure (independent of the underlying channel)
 *   - Authentication via CredentialsProvider
 *   - Dispatching all callbacks into the shared worker queue
 *
 * Subclasses of FSTStream implement serialization of models to and from bytes (via protocol
 * buffers) for a specific streaming RPC and emit events specific to the stream.
 *
 * ## Starting and Stopping
 *
 * Streaming RPCs are stateful and need to be started before messages can be sent and received.
 * The FSTStream will call its delegate's specific streamDidOpen method once the stream is ready
 * to accept requests.
 *
 * Should a `start` fail, FSTStream will call its delegate's specific streamDidClose method with an
 * NSError indicating what went wrong. The delegate is free to call start again.
 *
 * An FSTStream can also be explicitly stopped which indicates that the caller has discarded the
 * stream and no further events should be emitted. Once explicitly stopped, a stream cannot be
 * restarted.
 *
 * ## Subclassing Notes
 *
 * An implementation of FSTStream needs to implement the following methods:
 *   - `createRPCWithRequestsWriter`, should create the specific RPC (a GRPCCall object).
 *   - `handleStreamMessage`, receives protocol buffer responses from GRPC and must deserialize and
 *     delegate to some stream specific response method.
 *   - `notifyStreamOpen`, should call through to the stream-specific streamDidOpen method.
 *   - `notifyStreamInterrupted`, calls through to the stream-specific streamWasInterrupted method.
 *
 * Additionally, beyond these required methods, subclasses will want to implement methods that
 * take request models, serialize them, and write them to using writeRequest:. Implementation
 * specific cleanup logic can be added to tearDown:.
 *
 * ## RPC Message Type
 *
 * FSTStream intentionally uses the GRPCCall interface to GRPC directly, bypassing both GRPCProtoRPC
 * and GRXBufferedPipe for sending data. This has been done to avoid race conditions that come out
 * of a loosely specified locking contract on GRXWriter. There's essentially no way to safely use
 * any of the wrapper objects for GRXWriter (that perform buffering or conversion to/from protos).
 *
 * See https://github.com/grpc/grpc/issues/10957 for the kinds of things we're trying to avoid.
 */
@interface FSTStream <__covariant FSTStreamDelegate> : NSObject

- (instancetype)initWithDatabase:(const firebase::firestore::core::DatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
               connectionTimerID:(FSTTimerID)connectionTimerID
                     idleTimerID:(FSTTimerID)idleTimerID
                     credentials:(firebase::firestore::auth::CredentialsProvider *)credentials  // no passing ownership
            responseMessageClass:(Class)responseMessageClass NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/**
 * An abstract method used by `start` to create a streaming RPC specific to this type of stream.
 * The RPC should be created such that requests are taken from `self`.
 *
 * Note that the returned GRPCCall must not be a GRPCProtoRPC, since the rest of the streaming
 * mechanism assumes it is dealing in bytes-level requests and responses.
 */
- (GRPCCall *)createRPCWithRequestsWriter:(GRXWriter *)requestsWriter;

/**
 * Returns YES if `start` has been called and no error has occurred. YES indicates the stream is
 * open or in the process of opening (which encompasses respecting backoff, getting auth tokens,
 * and starting the actual RPC). Use `isOpen` to determine if the stream is open and ready for
 * outbound requests.
 */
- (BOOL)isStarted;

/** Returns YES if the underlying RPC is open and the stream is ready for outbound requests. */
- (BOOL)isOpen;

/**
 * Starts the RPC. Only allowed if isStarted returns NO. The stream is not immediately ready for
 * use: the delegate's watchStreamDidOpen method will be invoked when the RPC is ready for outbound
 * requests, at which point `isOpen` will return YES.
 *
 * When start returns, -isStarted will return YES.
 */
- (void)startWithDelegate:(id)delegate;

/**
 * Stops the RPC. This call is idempotent and allowed regardless of the current isStarted state.
 *
 * Unlike a transient stream close, stopping a stream is permanent. This is guaranteed NOT to emit
 * any further events on the stream-specific delegate, including the streamDidClose method.
 *
 * NOTE: This no-events contract may seem counter-intuitive but allows the caller to
 * straightforwardly sequence stream tear-down without having to worry about when the delegate's
 * streamDidClose methods will get called. For example if the stream must be exchanged for another
 * during a user change this allows `stop` to be called eagerly without worrying about the
 * streamDidClose method accidentally restarting the stream before the new one is ready.
 *
 * When stop returns, -isStarted and -isOpen will both return NO.
 */
- (void)stop;

/**
 * Marks this stream as idle. If no further actions are performed on the stream for one minute, the
 * stream will automatically close itself and notify the stream's close handler. The stream will
 * then be in a non-started state, requiring the caller to start the stream again before further
 * use.
 *
 * Only streams that are in state 'Open' can be marked idle, as all other states imply pending
 * network operations.
 */
- (void)markIdle;

/**
 * After an error the stream will usually back off on the next attempt to start it. If the error
 * warrants an immediate restart of the stream, the sender can use this to indicate that the
 * receiver should not back off.
 *
 * Each error will call the stream-specific streamDidClose method. That method can decide to
 * inhibit backoff if required.
 */
- (void)inhibitBackoff;

@end

#pragma mark - FSTWatchStream

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

/**
 * An FSTStream that implements the StreamingWatch RPC.
 *
 * Once the FSTWatchStream has called the streamDidOpen method, any number of watchQuery and
 * unwatchTargetId calls can be sent to control what changes will be sent from the server for
 * WatchChanges.
 */
@interface FSTWatchStream : FSTStream

/**
 * Initializes the watch stream with its dependencies.
 */
- (instancetype)initWithDatabase:(const firebase::firestore::core::DatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(firebase::firestore::auth::CredentialsProvider *)
                                     credentials  // no passsing ownership
                      serializer:(FSTSerializerBeta *)serializer NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithDatabase:(const firebase::firestore::core::DatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
               connectionTimerID:(FSTTimerID)connectionTimerID
                     idleTimerID:(FSTTimerID)idleTimerID
                     credentials:(firebase::firestore::auth::CredentialsProvider *)
                                     credentials  // no passing ownership
            responseMessageClass:(Class)responseMessageClass NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Registers interest in the results of the given query. If the query includes a resumeToken it
 * will be included in the request. Results that affect the query will be streamed back as
 * WatchChange messages that reference the targetID included in |query|.
 */
- (void)watchQuery:(FSTQueryData *)query;

/** Unregisters interest in the results of the query associated with the given target ID. */
- (void)unwatchTargetID:(FSTTargetID)targetID;

@end

#pragma mark - FSTWriteStream

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

/**
 * An FSTStream that implements the StreamingWrite RPC.
 *
 * The StreamingWrite RPC requires the caller to maintain special `streamToken` state in between
 * calls, to help the server understand which responses the client has processed by the time the
 * next request is made. Every response may contain a `streamToken`; this value must be passed to
 * the next request.
 *
 * After calling `start` on this stream, the next request must be a handshake, containing whatever
 * streamToken is on hand. Once a response to this request is received, all pending mutations may
 * be submitted. When submitting multiple batches of mutations at the same time, it's okay to use
 * the same streamToken for the calls to `writeMutations:`.
 */
@interface FSTWriteStream : FSTStream

/**
 * Initializes the write stream with its dependencies.
 */
- (instancetype)initWithDatabase:(const firebase::firestore::core::DatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                     credentials:(firebase::firestore::auth::CredentialsProvider *)
                                     credentials  // no passing ownership
                      serializer:(FSTSerializerBeta *)serializer;

- (instancetype)initWithDatabase:(const firebase::firestore::core::DatabaseInfo *)database
             workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
               connectionTimerID:(FSTTimerID)connectionTimerID
                     idleTimerID:(FSTTimerID)idleTimerID
                     credentials:(firebase::firestore::auth::CredentialsProvider *)
                                     credentials  // no passing ownership
            responseMessageClass:(Class)responseMessageClass NS_UNAVAILABLE;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Sends an initial streamToken to the server, performing the handshake required to make the
 * StreamingWrite RPC work. Subsequent `writeMutations:` calls should wait until a response has
 * been delivered to the delegate's writeStreamDidCompleteHandshake method.
 */
- (void)writeHandshake;

/** Sends a group of mutations to the Firestore backend to apply. */
- (void)writeMutations:(NSArray<FSTMutation *> *)mutations;

/**
 * Tracks whether or not a handshake has been successfully exchanged and the stream is ready to
 * accept mutations.
 */
@property(nonatomic, assign, readwrite, getter=isHandshakeComplete) BOOL handshakeComplete;

/**
 * The last received stream token from the server, used to acknowledge which responses the client
 * has processed. Stream tokens are opaque checkpoint markers whose only real value is their
 * inclusion in the next request.
 *
 * FSTWriteStream manages propagating this value from responses to the next request.
 */
@property(nonatomic, strong, nullable) NSData *lastStreamToken;

@end

NS_ASSUME_NONNULL_END
