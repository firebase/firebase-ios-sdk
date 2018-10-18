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

#import "Firestore/Example/Tests/SpecTests/FSTMockDatastore.h"

#include <map>
#include <memory>
#include <queue>
#include <utility>

#import "Firestore/Source/Core/FSTQuery.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Model/FSTMutation.h"
#import "Firestore/Source/Remote/FSTSerializerBeta.h"
#import "Firestore/Source/Remote/FSTStream.h"
#import "Firestore/Source/Util/FSTDispatchQueue.h"

#import "Firestore/Example/Tests/Remote/FSTWatchChange+Testing.h"

#include "Firestore/core/src/firebase/firestore/auth/credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/auth/empty_credentials_provider.h"
#include "Firestore/core/src/firebase/firestore/core/database_info.h"
#include "Firestore/core/src/firebase/firestore/model/database_id.h"
#include "Firestore/core/src/firebase/firestore/remote/connectivity_monitor.h"
#include "Firestore/core/src/firebase/firestore/remote/grpc_connection.h"
#include "Firestore/core/src/firebase/firestore/remote/stream.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "absl/memory/memory.h"
#include "grpcpp/completion_queue.h"

using firebase::firestore::auth::CredentialsProvider;
using firebase::firestore::auth::EmptyCredentialsProvider;
using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::SnapshotVersion;

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTMockWatchStream

namespace firebase {
namespace firestore {
namespace remote {

using model::TargetId;
using util::AsyncQueue;

namespace {

class MockConnectivityMonitor : public ConnectivityMonitor {
 public:
  MockConnectivityMonitor() : ConnectivityMonitor{nullptr} {
  }
};

}  // namespace

class MockWatchStream : public WatchStream {
 public:
  MockWatchStream(AsyncQueue *worker_queue,
                  CredentialsProvider *credentials_provider,
                  FSTSerializerBeta *serializer,
                  GrpcConnection *grpc_connection,
                  id<FSTWatchStreamDelegate> delegate,
                  FSTMockDatastore *datastore)
      : WatchStream{worker_queue, credentials_provider, serializer, grpc_connection, delegate},
        datastore_{datastore},
        delegate_{delegate} {
    active_targets_ = [NSMutableDictionary dictionary];
  }

  NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *ActiveTargets() {
    return [active_targets_ copy];
  }

  void Start() override {
    HARD_ASSERT(!open_, "Trying to start already started watch stream");
    open_ = true;
    [delegate_ watchStreamDidOpen];
  }

  void Stop() override {
    WatchStream::Stop();
    open_ = false;
    [active_targets_ removeAllObjects];
  }

  bool IsStarted() const override {
    return open_;
  }
  bool IsOpen() const override {
    return open_;
  }

  void WatchQuery(FSTQueryData *query) override {
    LOG_DEBUG("WatchQuery: %s: %s, %s", query.targetID, query.query, query.resumeToken);

    // Snapshot version is ignored on the wire
    FSTQueryData *sentQueryData = [query queryDataByReplacingSnapshotVersion:SnapshotVersion::None()
                                                                 resumeToken:query.resumeToken
                                                              sequenceNumber:query.sequenceNumber];
    datastore_.watchStreamRequestCount += 1;
    active_targets_[@(query.targetID)] = sentQueryData;
  }

  void UnwatchTargetId(model::TargetId target_id) override {
    LOG_DEBUG("UnwatchTargetId: %s", target_id);
    [active_targets_ removeObjectForKey:@(target_id)];
  }

  void FailStreamWithError(NSError *error) {
    open_ = false;
    [delegate_ watchStreamWasInterruptedWithError:error];
  }

  void WriteWatchChange(FSTWatchChange *change, SnapshotVersion snap) {
    if ([change isKindOfClass:[FSTWatchTargetChange class]]) {
      FSTWatchTargetChange *targetChange = (FSTWatchTargetChange *)change;
      if (targetChange.cause) {
        for (NSNumber *target_id in targetChange.targetIDs) {
          if (!active_targets_[target_id]) {
            // Technically removing an unknown target is valid (e.g. it could race with a
            // server-side removal), but we want to pay extra careful attention in tests
            // that we only remove targets we listened to.
            HARD_FAIL("Removing a non-active target");
          }

          [active_targets_ removeObjectForKey:target_id];
        }
      }

      if ([targetChange.targetIDs count] != 0) {
        // If the list of target IDs is not empty, we reset the snapshot version to NONE as
        // done in `FSTSerializerBeta.versionFromListenResponse:`.
        snap = SnapshotVersion::None();
      }
    }

    [delegate_ watchStreamDidChange:change snapshotVersion:snap];
  }

 private:
  bool open_ = false;
  NSMutableDictionary<FSTBoxedTargetID *, FSTQueryData *> *active_targets_ = nullptr;
  FSTMockDatastore *datastore_ = nullptr;
  id<FSTWatchStreamDelegate> delegate_ = nullptr;
};

class MockWriteStream : public WriteStream {
 public:
  MockWriteStream(AsyncQueue *worker_queue,
                  CredentialsProvider *credentials_provider,
                  FSTSerializerBeta *serializer,
                  GrpcConnection *grpc_connection,
                  id<FSTWriteStreamDelegate> delegate,
                  FSTMockDatastore *datastore)
      : WriteStream{worker_queue, credentials_provider, serializer, grpc_connection, delegate},
        datastore_{datastore},
        delegate_{delegate} {
  }

  void Start() override {
    HARD_ASSERT(!open_, "Trying to start already started write stream");
    open_ = true;
    sent_mutations_ = {};
    [delegate_ writeStreamDidOpen];
  }
  
  void Stop() override {
    datastore_.writeStreamRequestCount += 1;
    WriteStream::Stop();

    sent_mutations_ = {};
    open_ = false;
    SetHandshakeComplete(false);
  }

  bool IsStarted() const override {
    return open_;
  }
  bool IsOpen() const override {
    return open_;
  }

  void WriteHandshake() override {
    datastore_.writeStreamRequestCount += 1;
    SetHandshakeComplete();
    [delegate_ writeStreamDidCompleteHandshake];
  }

  void WriteMutations(NSArray<FSTMutation *> *mutations) override {
    datastore_.writeStreamRequestCount += 1;
    sent_mutations_.push(mutations);
  }

  /** Injects a write ack as though it had come from the backend in response to a write. */
  void AckWrite(const SnapshotVersion &commitVersion, NSArray<FSTMutationResult *> *results) {
    [delegate_ writeStreamDidReceiveResponseWithVersion:commitVersion mutationResults:results];
  }

  /** Injects a failed write response as though it had come from the backend. */
  void FailStreamWithError(NSError *error) {
    open_ = false;
    [delegate_ writeStreamWasInterruptedWithError:error];
  }

  /**
   * Returns the next write that was "sent to the backend", failing if there are no queued sent
   */
  NSArray<FSTMutation *> *NextSentWrite() {
    HARD_ASSERT(!sent_mutations_.empty(),
                "Writes need to happen before you can call NextSentWrite.");
    NSArray<FSTMutation *> *result = std::move(sent_mutations_.front());
    sent_mutations_.pop();
    return result;
  }

  /**
   * Returns the number of mutations that have been sent to the backend but not retrieved via
   * nextSentWrite yet.
   */
  int SentMutationsCount() const {
    return static_cast<int>(sent_mutations_.size());
  }

 private:
  bool open_ = false;
  std::queue<NSArray<FSTMutation *> *> sent_mutations_;
  FSTMockDatastore *datastore_ = nullptr;
  id<FSTWriteStreamDelegate> delegate_ = nullptr;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

@interface FSTMockDatastore ()

/** Properties implemented in FSTDatastore that are nonpublic. */
@property(nonatomic, strong, readonly) FSTDispatchQueue *workerDispatchQueue;
@property(nonatomic, assign, readonly) CredentialsProvider *credentials;

@end

@implementation FSTMockDatastore {
  std::shared_ptr<firebase::firestore::remote::MockWatchStream> _watchStream;
  std::shared_ptr<firebase::firestore::remote::MockWriteStream> _writeStream;

  std::unique_ptr<firebase::firestore::remote::MockConnectivityMonitor> _connectivityMonitor;
  grpc::CompletionQueue _grpcQueue;
  std::unique_ptr<firebase::firestore::remote::GrpcConnection> _grpcConnection;
}

#pragma mark - Overridden FSTDatastore methods.

- (instancetype)initWithDatabaseInfo:(const DatabaseInfo *)databaseInfo
                 workerDispatchQueue:(FSTDispatchQueue *)workerDispatchQueue
                         credentials:(CredentialsProvider *)credentials {
  if (self = [super initWithDatabaseInfo:databaseInfo
                     workerDispatchQueue:workerDispatchQueue
                             credentials:credentials]) {
    _workerDispatchQueue = workerDispatchQueue;
    _credentials = credentials;
    _connectivityMonitor =
        absl::make_unique<firebase::firestore::remote::MockConnectivityMonitor>();
    _grpcConnection = absl::make_unique<firebase::firestore::remote::GrpcConnection>(
        *databaseInfo, [workerDispatchQueue implementation], &_grpcQueue,
        _connectivityMonitor.get());
  }
  return self;
}

- (std::shared_ptr<firebase::firestore::remote::WatchStream>)createWatchStreamWithDelegate:
    (id<FSTWatchStreamDelegate>)delegate {
  _watchStream = std::make_shared<firebase::firestore::remote::MockWatchStream>(
      [self.workerDispatchQueue implementation], self.credentials,
      [[FSTSerializerBeta alloc] initWithDatabaseID:&self.databaseInfo->database_id()],
      _grpcConnection.get(), delegate, self);

  return _watchStream;
}

- (std::shared_ptr<firebase::firestore::remote::WriteStream>)createWriteStreamWithDelegate:
    (id<FSTWriteStreamDelegate>)delegate {
  _writeStream = std::make_shared<firebase::firestore::remote::MockWriteStream>(
      [self.workerDispatchQueue implementation], self.credentials,
      [[FSTSerializerBeta alloc] initWithDatabaseID:&self.databaseInfo->database_id()],
      _grpcConnection.get(), delegate, self);

  return _writeStream;
}

#pragma mark - Method exposed for tests to call.

- (NSArray<FSTMutation *> *)nextSentWrite {
  return _writeStream->NextSentWrite();
}

- (int)writesSent {
  return _writeStream->SentMutationsCount();
}

- (void)ackWriteWithVersion:(const SnapshotVersion &)version
            mutationResults:(NSArray<FSTMutationResult *> *)results {
  _writeStream->AckWrite(version, results);
}

- (void)failWriteWithError:(NSError *_Nullable)error {
  _writeStream->FailStreamWithError(error);
}

- (void)writeWatchChange:(FSTWatchChange *)change snapshotVersion:(const SnapshotVersion &)snap {
  _watchStream->WriteWatchChange(change, snap);
}

- (void)failWatchStreamWithError:(NSError *)error {
  _watchStream->FailStreamWithError(error);
}

- (NSDictionary<FSTBoxedTargetID *, FSTQueryData *> *)activeTargets {
  return _watchStream->ActiveTargets();
}

- (BOOL)isWatchStreamOpen {
  return _watchStream->IsOpen();
}

@end

NS_ASSUME_NONNULL_END
