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

#include "Firestore/core/src/core/database_info.h"
#include "Firestore/core/src/credentials/credentials_provider.h"
#include "Firestore/core/src/credentials/empty_credentials_provider.h"
#include "Firestore/core/src/local/target_data.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/model/mutation.h"
#include "Firestore/core/src/remote/connectivity_monitor.h"
#include "Firestore/core/src/remote/datastore.h"
#include "Firestore/core/src/remote/firebase_metadata_provider.h"
#include "Firestore/core/src/remote/grpc_connection.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/remote/stream.h"
#include "Firestore/core/src/util/async_queue.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/remote/create_noop_connectivity_monitor.h"
#include "absl/memory/memory.h"
#include "grpcpp/completion_queue.h"

NS_ASSUME_NONNULL_BEGIN

using firebase::firestore::core::DatabaseInfo;
using firebase::firestore::credentials::AppCheckCredentialsProvider;
using firebase::firestore::credentials::AuthCredentialsProvider;
using firebase::firestore::credentials::EmptyCredentialsProvider;
using firebase::firestore::local::TargetData;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::model::Mutation;
using firebase::firestore::model::MutationResult;
using firebase::firestore::model::SnapshotVersion;
using firebase::firestore::model::TargetId;
using firebase::firestore::remote::ConnectivityMonitor;
using firebase::firestore::remote::FirebaseMetadataProvider;
using firebase::firestore::remote::GrpcConnection;
using firebase::firestore::remote::WatchChange;
using firebase::firestore::remote::WatchStream;
using firebase::firestore::remote::WatchTargetChange;
using firebase::firestore::remote::WriteStream;
using firebase::firestore::util::AsyncQueue;
using firebase::firestore::util::Status;

namespace firebase {
namespace firestore {
namespace remote {

class MockWatchStream : public WatchStream {
 public:
  MockWatchStream(const std::shared_ptr<AsyncQueue>& worker_queue,
                  std::shared_ptr<AuthCredentialsProvider> auth_credentials_provider,
                  std::shared_ptr<AppCheckCredentialsProvider> app_check_credentials_provider,
                  Serializer serializer,
                  GrpcConnection* grpc_connection,
                  WatchStreamCallback* callback,
                  MockDatastore* datastore)
      : WatchStream{worker_queue,
                    auth_credentials_provider,
                    app_check_credentials_provider,
                    std::move(serializer),
                    grpc_connection,
                    callback},
        datastore_{datastore},
        callback_{callback} {
  }

  const std::unordered_map<TargetId, TargetData>& ActiveTargets() const {
    return active_targets_;
  }

  void Start() override {
    HARD_ASSERT(!open_, "Trying to start already started watch stream");
    open_ = true;
    callback_->OnWatchStreamOpen();
  }

  void Stop() override {
    WatchStream::Stop();
    open_ = false;
    active_targets_.clear();
  }

  bool IsStarted() const override {
    return open_;
  }
  bool IsOpen() const override {
    return open_;
  }

  void WatchQuery(const TargetData& query) override {
    LOG_DEBUG("WatchQuery: %s: %s, %s", query.target_id(), query.target().ToString(),
              query.resume_token().ToString());

    // Snapshot version is ignored on the wire
    TargetData sentTargetData =
        query.WithResumeToken(query.resume_token(), SnapshotVersion::None());
    datastore_->IncrementWatchStreamRequests();
    active_targets_[query.target_id()] = sentTargetData;
  }

  void UnwatchTargetId(model::TargetId target_id) override {
    LOG_DEBUG("UnwatchTargetId: %s", target_id);
    active_targets_.erase(target_id);
  }

  void FailStream(const Status& error) {
    open_ = false;
    callback_->OnWatchStreamClose(error);
  }

  void WriteWatchChange(const WatchChange& change, SnapshotVersion snap) {
    if (change.type() == WatchChange::Type::TargetChange) {
      const auto& targetChange = static_cast<const WatchTargetChange&>(change);
      if (!targetChange.cause().ok()) {
        for (TargetId target_id : targetChange.target_ids()) {
          auto found = active_targets_.find(target_id);
          if (found == active_targets_.end()) {
            // Technically removing an unknown target is valid (e.g. it could race with a
            // server-side removal), but we want to pay extra careful attention in tests
            // that we only remove targets we listened to.
            HARD_FAIL("Removing a non-active target");
          }

          active_targets_.erase(found);
        }
      }

      if (!targetChange.target_ids().empty()) {
        // If the list of target IDs is not empty, we reset the snapshot version to NONE as
        // done in `Serializer::DecodeVersion:`.
        snap = SnapshotVersion::None();
      }
    }

    callback_->OnWatchStreamChange(change, snap);
  }

 private:
  bool open_ = false;
  std::unordered_map<TargetId, TargetData> active_targets_;
  MockDatastore* datastore_ = nullptr;
  WatchStreamCallback* callback_ = nullptr;
};

class MockWriteStream : public WriteStream {
 public:
  MockWriteStream(const std::shared_ptr<AsyncQueue>& worker_queue,
                  std::shared_ptr<AuthCredentialsProvider> auth_credentials_provider,
                  std::shared_ptr<AppCheckCredentialsProvider> app_check_credentials_provider,
                  Serializer serializer,
                  GrpcConnection* grpc_connection,
                  WriteStreamCallback* callback,
                  MockDatastore* datastore)
      : WriteStream{worker_queue,
                    auth_credentials_provider,
                    app_check_credentials_provider,
                    std::move(serializer),
                    grpc_connection,
                    callback},
        datastore_{datastore},
        callback_{callback} {
  }

  void Start() override {
    HARD_ASSERT(!open_, "Trying to start already started write stream");
    open_ = true;
    sent_mutations_ = {};
    callback_->OnWriteStreamOpen();
  }

  void Stop() override {
    datastore_->IncrementWriteStreamRequests();
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
    datastore_->IncrementWriteStreamRequests();
    SetHandshakeComplete();
    callback_->OnWriteStreamHandshakeComplete();
  }

  void WriteMutations(const std::vector<Mutation>& mutations) override {
    datastore_->IncrementWriteStreamRequests();
    sent_mutations_.push(mutations);
  }

  /** Injects a write ack as though it had come from the backend in response to a write. */
  void AckWrite(const SnapshotVersion& commitVersion, std::vector<MutationResult> results) {
    callback_->OnWriteStreamMutationResult(commitVersion, std::move(results));
  }

  /** Injects a failed write response as though it had come from the backend. */
  void FailStream(const Status& error) {
    open_ = false;
    callback_->OnWriteStreamClose(error);
  }

  /**
   * Returns the next write that was "sent to the backend", failing if there are no queued sent
   */
  std::vector<Mutation> NextSentWrite() {
    HARD_ASSERT(!sent_mutations_.empty(),
                "Writes need to happen before you can call NextSentWrite.");
    std::vector<Mutation> result = std::move(sent_mutations_.front());
    sent_mutations_.pop();
    return result;
  }

  /**
   * Returns the number of mutations that have been sent to the backend but not retrieved via
   * nextSentWrite yet.
   */
  int sent_mutations_count() const {
    return static_cast<int>(sent_mutations_.size());
  }

 private:
  bool open_ = false;
  std::queue<std::vector<Mutation>> sent_mutations_;
  MockDatastore* datastore_ = nullptr;
  WriteStreamCallback* callback_ = nullptr;
};

MockDatastore::MockDatastore(
    const core::DatabaseInfo& database_info,
    const std::shared_ptr<util::AsyncQueue>& worker_queue,
    std::shared_ptr<credentials::AuthCredentialsProvider> auth_credentials,
    std::shared_ptr<credentials::AppCheckCredentialsProvider> app_check_credentials,
    ConnectivityMonitor* connectivity_monitor,
    FirebaseMetadataProvider* firebase_metadata_provider)
    : Datastore{database_info,         worker_queue,         auth_credentials,
                app_check_credentials, connectivity_monitor, firebase_metadata_provider},
      database_info_{&database_info},
      worker_queue_{worker_queue},
      app_check_credentials_{app_check_credentials},
      auth_credentials_{auth_credentials} {
}

std::shared_ptr<WatchStream> MockDatastore::CreateWatchStream(WatchStreamCallback* callback) {
  watch_stream_ = std::make_shared<MockWatchStream>(
      worker_queue_, auth_credentials_, app_check_credentials_,
      Serializer{database_info_->database_id()}, grpc_connection(), callback, this);

  return watch_stream_;
}

std::shared_ptr<WriteStream> MockDatastore::CreateWriteStream(WriteStreamCallback* callback) {
  write_stream_ = std::make_shared<MockWriteStream>(
      worker_queue_, auth_credentials_, app_check_credentials_,
      Serializer{database_info_->database_id()}, grpc_connection(), callback, this);

  return write_stream_;
}

void MockDatastore::WriteWatchChange(const WatchChange& change, const SnapshotVersion& snap) {
  watch_stream_->WriteWatchChange(change, snap);
}

void MockDatastore::FailWatchStream(const Status& error) {
  watch_stream_->FailStream(error);
}

const std::unordered_map<TargetId, TargetData>& MockDatastore::ActiveTargets() const {
  return watch_stream_->ActiveTargets();
}

bool MockDatastore::IsWatchStreamOpen() const {
  return watch_stream_->IsOpen();
}

std::vector<Mutation> MockDatastore::NextSentWrite() {
  return write_stream_->NextSentWrite();
}

int MockDatastore::WritesSent() const {
  return write_stream_->sent_mutations_count();
}

void MockDatastore::AckWrite(const SnapshotVersion& version, std::vector<MutationResult> results) {
  write_stream_->AckWrite(version, std::move(results));
}

void MockDatastore::FailWrite(const Status& error) {
  write_stream_->FailStream(error);
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
