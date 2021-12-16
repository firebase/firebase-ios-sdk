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

#include <memory>
#include <unordered_map>
#include <vector>

#include "Firestore/core/src/model/model_fwd.h"
#include "Firestore/core/src/remote/datastore.h"
#include "Firestore/core/src/util/status_fwd.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace remote {

class ConnectivityMonitor;
class FirebaseMetadataProvider;
class MockWatchStream;
class MockWriteStream;

class MockDatastore : public Datastore {
 public:
  MockDatastore(const core::DatabaseInfo& database_info,
                const std::shared_ptr<util::AsyncQueue>& worker_queue,
                std::shared_ptr<credentials::AuthCredentialsProvider> auth_credentials,
                std::shared_ptr<credentials::AppCheckCredentialsProvider> app_check_credentials,
                ConnectivityMonitor* connectivity_monitor,
                FirebaseMetadataProvider* firebase_metadata_provider);

  std::shared_ptr<WatchStream> CreateWatchStream(WatchStreamCallback* callback) override;
  std::shared_ptr<WriteStream> CreateWriteStream(WriteStreamCallback* callback) override;

  /**
   * A count of the total number of requests sent to the watch stream since the beginning of the
   * test case.
   */
  int watch_stream_request_count() const {
    return watch_stream_request_count_;
  }
  /**
   * A count of the total number of requests sent to the write stream since the beginning of the
   * test case.
   */
  int write_stream_request_count() const {
    return write_stream_request_count_;
  }

  void IncrementWatchStreamRequests() {
    ++watch_stream_request_count_;
  }
  void IncrementWriteStreamRequests() {
    ++write_stream_request_count_;
  }

  /** Injects a WatchChange as though it had come from the backend. */
  void WriteWatchChange(const WatchChange& change, const model::SnapshotVersion& snap);
  /** Injects a stream failure as though it had come from the backend. */
  void FailWatchStream(const util::Status& error);

  /** Returns the set of active targets on the watch stream. */
  const std::unordered_map<model::TargetId, local::TargetData>& ActiveTargets() const;
  /** Helper method to expose watch stream state to verify in tests. */
  bool IsWatchStreamOpen() const;

  /**
   * Returns the next write that was "sent to the backend", failing if there are no queued sent
   */
  std::vector<model::Mutation> NextSentWrite();
  /** Returns the number of writes that have been sent to the backend but not waited on yet. */
  int WritesSent() const;

  /** Injects a write ack as though it had come from the backend in response to a write. */
  void AckWrite(const model::SnapshotVersion& version, std::vector<model::MutationResult> results);

  /** Injects a stream failure as though it had come from the backend. */
  void FailWrite(const util::Status& error);

 private:
  // These are all passed to the base class; however, making `MockDatastore` store the pointers
  // reduces the number of test-only methods in `Datastore`.
  const core::DatabaseInfo* database_info_ = nullptr;
  std::shared_ptr<util::AsyncQueue> worker_queue_;
  std::shared_ptr<credentials::AppCheckCredentialsProvider> app_check_credentials_;
  std::shared_ptr<credentials::AuthCredentialsProvider> auth_credentials_;

  std::shared_ptr<MockWatchStream> watch_stream_;
  std::shared_ptr<MockWriteStream> write_stream_;

  int watch_stream_request_count_ = 0;
  int write_stream_request_count_ = 0;
};

}  // namespace remote
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END
