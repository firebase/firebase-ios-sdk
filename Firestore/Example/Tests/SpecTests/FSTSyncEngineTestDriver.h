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

#include <cstddef>
#include <map>
#include <memory>
#include <unordered_map>
#include <utility>
#include <vector>

#include "Firestore/core/src/api/load_bundle_task.h"
#include "Firestore/core/src/bundle/bundle_reader.h"
#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/core/query.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/src/credentials/user.h"
#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/nanopb/byte_string.h"
#include "Firestore/core/src/nanopb/nanopb_util.h"
#include "Firestore/core/src/remote/watch_change.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/empty.h"

namespace firebase {
namespace firestore {
namespace local {

class Persistence;
class TargetData;

}  // namespace local
}  // namespace firestore
}  // namespace firebase

namespace api = firebase::firestore::api;
namespace bundle = firebase::firestore::bundle;
namespace core = firebase::firestore::core;
namespace credentials = firebase::firestore::credentials;
namespace local = firebase::firestore::local;
namespace model = firebase::firestore::model;
namespace remote = firebase::firestore::remote;

// A map holds expected information about currently active targets. The keys are
// target ID, and the values are a vector of `TargetData`s mapped to the target.
using ActiveTargetMap = std::unordered_map<model::TargetId, std::vector<local::TargetData>>;

NS_ASSUME_NONNULL_BEGIN

/**
 * Interface used for object that contain exactly one of either a view snapshot or an error for the
 * given query.
 */
@interface FSTQueryEvent : NSObject
@property(nonatomic, assign) core::Query query;
@property(nonatomic, strong, nullable) NSError *error;

- (const absl::optional<core::ViewSnapshot> &)viewSnapshot;
- (void)setViewSnapshot:(absl::optional<core::ViewSnapshot>)snapshot;

@end

/** Holds an outstanding write and its result. */
@interface FSTOutstandingWrite : NSObject

/** The write that is outstanding. */
- (const model::Mutation &)write;
- (void)setWrite:(model::Mutation)write;

/** Whether this write is done (regardless of whether it was successful or not). */
@property(nonatomic, assign, readwrite) BOOL done;

/** The error - if any - of this write. */
@property(nonatomic, strong, nullable, readwrite) NSError *error;

@end

/** Mapping of user => array of FSTMutations for that user. */
typedef std::
    unordered_map<credentials::User, NSMutableArray<FSTOutstandingWrite *> *, credentials::HashUser>
        FSTOutstandingWriteQueues;

/**
 * A test driver for FSTSyncEngine that allows simulated event delivery and capture. As much as
 * possible, all sources of nondeterminism are removed so that test execution is consistent and
 * reliable.
 *
 * FSTSyncEngineTestDriver:
 *
 * + constructs an FSTSyncEngine using a mocked Datastore for the backend;
 * + allows the caller to trigger events (user API calls and incoming Datastore messages);
 * + performs sequencing validation internally (e.g. that when a user mutation is initiated, the
 *   FSTSyncEngine correctly sends it to the remote store); and
 * + exposes the set of FSTQueryEvents generated for the caller to verify.
 *
 * Events come in three major flavors:
 *
 * + user events: simulate user API calls
 * + watch events: simulate RPC interactions with the Watch backend
 * + write events: simulate RPC interactions with the Streaming Write backend
 *
 * Each method on the driver injects a different event into the system.
 */
@interface FSTSyncEngineTestDriver : NSObject

/**
 * Initializes the underlying FSTSyncEngine with the given local persistence implementation and
 * a set of existing outstandingWrites (useful when your Persistence object has persisted
 * mutation queues).
 */
- (instancetype)initWithPersistence:(std::unique_ptr<local::Persistence>)persistence
                            eagerGC:(BOOL)eagerGC
                        initialUser:(const credentials::User &)initialUser
                  outstandingWrites:(const FSTOutstandingWriteQueues &)outstandingWrites
      maxConcurrentLimboResolutions:(size_t)maxConcurrentLimboResolutions NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** Starts the FSTSyncEngine and its underlying components. */
- (void)start;

/** Validates that the API has been used correctly after a test is complete. */
- (void)validateUsage;

/** Shuts the FSTSyncEngine down. */
- (void)shutdown;

/**
 * Adds a listener to the FSTSyncEngine as if the user had initiated a new listen for the given
 * query.
 *
 * Resulting events are captured and made available via the capturedEventsSinceLastCall method.
 *
 * @param query A valid query to execute against the backend.
 * @param options A listen option to configure snapshot listener.
 * @return The target ID assigned by the system to track the query.
 */
- (model::TargetId)addUserListenerWithQuery:(core::Query)query options:(core::ListenOptions)options;

/**
 * Removes a listener from the FSTSyncEngine as if the user had removed a listener corresponding
 * to the given query.
 *
 * Resulting events are captured and made available via the capturedEventsSinceLastCall method.
 *
 * @param query An identical query corresponding to one passed to -addUserListenerWithQuery.
 */
- (void)removeUserListenerWithQuery:(const core::Query &)query;

/**
 * Loads a Firestore bundle captured in `reader` into the local storage.
 *
 * Resulting events are captured and made available via the capturedEventsSinceLastCall method.
 *
 * @param reader An object to read from the underlying input stream of the bundle.
 * @param task An object to report loading progress and result.
 */
- (void)loadBundleWithReader:(std::shared_ptr<bundle::BundleReader>)reader
                        task:(std::shared_ptr<api::LoadBundleTask>)task;

/**
 * Delivers a WatchChange RPC to the FSTSyncEngine as if it were received from the backend watch
 * service, either in response to addUserListener: or removeUserListener calls or because the
 * simulated backend has new data.
 *
 * Resulting events are captured and made available via the capturedEventsSinceLastCall method.
 *
 * @param change Any type of watch change
 * @param snapshot A snapshot version to attach, if applicable. This should be sent when
 *      simulating the server having sent a complete snapshot.
 */
- (void)receiveWatchChange:(const remote::WatchChange &)change
           snapshotVersion:(const model::SnapshotVersion &)snapshot;

/**
 * Delivers a watch stream error as if the Streaming Watch backend has generated some kind of error.
 *
 * @param errorCode A FIRFirestoreErrorCode value, from FIRFirestoreErrors.h
 * @param userInfo Any additional details that the server might have sent along with the error.
 *     For the moment this is effectively unused, but is logged.
 */
- (void)receiveWatchStreamError:(int)errorCode userInfo:(NSDictionary<NSString *, id> *)userInfo;

/**
 * Performs a mutation against the FSTSyncEngine as if the user had written the mutation through
 * the API.
 *
 * Also retains the mutation so that the driver can validate that the sync engine sent the mutation
 * to the remote store before receiveWatchChange:snapshotVersion: and receiveWriteError:userInfo:
 * events are processed.
 *
 * @param mutation Any type of valid mutation.
 */
- (void)writeUserMutation:(model::Mutation)mutation;

/**
 * Delivers a write error as if the Streaming Write backend has generated some kind of error.
 *
 * For the moment write errors are usually must be in response to a mutation that has been written
 * with writeUserMutation:. Spontaneously errors due to idle timeout, server restart, or credential
 * expiration aren't yet supported.
 *
 * @param errorCode A FIRFirestoreErrorCode value, from FIRFirestoreErrors.h
 * @param userInfo Any additional details that the server might have sent along with the error.
 *     For the moment this is effectively unused, but is logged.
 * @param keepInQueue Whether to keep the write in the write queue as it will be retried.
 */
- (FSTOutstandingWrite *)receiveWriteError:(int)errorCode
                                  userInfo:(NSDictionary<NSString *, id> *)userInfo
                               keepInQueue:(BOOL)keepInQueue;

/**
 * Delivers a write acknowledgement as if the Streaming Write backend has acknowledged a write with
 * the snapshot version at which the write was committed.
 *
 * @param commitVersion The snapshot version at which the simulated server has committed
 *     the mutation. Snapshot versions must be monotonically increasing.
 * @param mutationResults The mutation results for the write that is being acked.
 */
- (FSTOutstandingWrite *)receiveWriteAckWithVersion:(const model::SnapshotVersion &)commitVersion
                                    mutationResults:
                                        (std::vector<model::MutationResult>)mutationResults;

/**
 * A count of the mutations written to the write stream by the FSTSyncEngine, but not yet
 * acknowledged via receiveWriteError: or receiveWriteAckWithVersion:mutationResults.
 */
@property(nonatomic, readonly) int sentWritesCount;

/**
 * A count of the total number of requests sent to the write stream since the beginning of the test
 * case.
 */
@property(nonatomic, readonly) int writeStreamRequestCount;

/**
 * A count of the total number of requests sent to the watch stream since the beginning of the test
 * case.
 */
@property(nonatomic, readonly) int watchStreamRequestCount;

/**
 * Disables RemoteStore's network connection and shuts down all streams.
 */
- (void)disableNetwork;

/**
 * Enables RemoteStore's network connection.
 */
- (void)enableNetwork;

/**
 * Runs a pending timer callback on the worker queue.
 */
- (void)runTimer:(firebase::firestore::util::TimerId)timerID;

/**
 * Triggers a LRU GC run with given cache threshold.
 */
- (void)triggerLruGC:(NSNumber *)threshold;

/**
 * Switches the FSTSyncEngine to a new user. The test driver tracks the outstanding mutations for
 * each user, so future receiveWriteAck/Error operations will validate the write sent to the mock
 * datastore matches the next outstanding write for that user.
 */
- (void)changeUser:(const credentials::User &)user;

/**
 * Drains the client's dispatch queue.
 */
- (void)drainQueue;

/**
 * Returns all query events generated by the FSTSyncEngine in response to the event injection
 * methods called previously. The events are cleared after each invocation of this method.
 */
- (NSArray<FSTQueryEvent *> *)capturedEventsSinceLastCall;

/**
 * Returns the names of the documents that the client acknowledged since the last call to this
 * method. The keys are cleared after each invocation of this method.
 */
- (NSArray<NSString *> *)capturedAcknowledgedWritesSinceLastCall;

/**
 * Returns the names of the documents that the client rejected since the last call to this
 * method. The keys are cleared after each invocation of this method.
 */
- (NSArray<NSString *> *)capturedRejectedWritesSinceLastCall;

/** The current set of documents in limbo with active targets. */
- (std::map<model::DocumentKey, model::TargetId>)activeLimboDocumentResolutions;

/** The current set of documents in limbo that are enqueued for resolution. */
- (std::vector<model::DocumentKey>)enqueuedLimboDocumentResolutions;

/** The expected set of documents in limbo with an active target. */
- (const model::DocumentKeySet &)expectedActiveLimboDocuments;

/** Sets the expected set of documents in limbo with an active target. */
- (void)setExpectedActiveLimboDocuments:(model::DocumentKeySet)docs;

/** The expected set of documents in limbo that are enqueued for resolution. */
- (const model::DocumentKeySet &)expectedEnqueuedLimboDocuments;

/** Sets the expected set of documents in limbo that are enqueued for resolution. */
- (void)setExpectedEnqueuedLimboDocuments:(model::DocumentKeySet)docs;

/**
 * The writes that have been sent to the FSTSyncEngine via writeUserMutation: but not yet
 * acknowledged by calling receiveWriteAck/Error:. They are tracked per-user.
 *
 * It is mostly an implementation detail used internally to validate that the writes sent to the
 * mock backend by the FSTSyncEngine match the user mutations that initiated them.
 *
 * It is exposed specifically for use with the
 * initWithPersistence:GCEnabled:outstandingWrites: initializer to test persistence
 * scenarios where the FSTSyncEngine is restarted while the Persistence implementation still has
 * outstanding persisted mutations.
 *
 * Note: The size of the list for the current user will generally be the same as
 * sentWritesCount, but not necessarily, since the `RemoteStore` limits the number of
 * outstanding writes to the backend at a given time.
 */
@property(nonatomic, assign, readonly) const FSTOutstandingWriteQueues &outstandingWrites;

/** The current user for the FSTSyncEngine; determines which mutation queue is active. */
@property(nonatomic, assign, readonly) const credentials::User &currentUser;

/**
 * The number of waitForPendingWrites events that have been received.
 */
@property(nonatomic, readonly) int waitForPendingWritesEvents;

/**
 * The DatabaseInfo of the Firestore instance.
 */
@property(nonatomic, readonly) const core::DatabaseInfo &databaseInfo;

- (void)incrementWaitForPendingWritesEvents;

- (void)resetWaitForPendingWritesEvents;

/**
 * Register a new waitForPendingWrites() callback.
 */
- (void)waitForPendingWrites;

/**
 * The number of snapshots-in-sync events that have been received.
 */
@property(nonatomic, readonly) int snapshotsInSyncEvents;

- (void)incrementSnapshotsInSyncEvents;

- (void)resetSnapshotsInSyncEvents;

/**
 * Adds a snpahots-in-sync listener to the event manager and keeps track of it so that it
 * can be easily removed later.
 */
- (void)addSnapshotsInSyncListener;

/**
 * Removes the snapshots-in-sync listener from the event manager.
 */
- (void)removeSnapshotsInSyncListener;

/** The set of active targets as observed on the watch stream. */
- (const std::unordered_map<model::TargetId, local::TargetData> &)activeTargets;

/** The expected set of active targets, keyed by target ID. */
- (const ActiveTargetMap &)expectedActiveTargets;

- (void)setExpectedActiveTargets:(ActiveTargetMap)targets;

@end

NS_ASSUME_NONNULL_END
