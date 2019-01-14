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
#include "Firestore/core/src/firebase/firestore/model/types.h"

class MockDatastore : public Datastore {
 public:
  MockDatastore(const core::DatabaseInfo& database_info,
                util::AsyncQueue* worker_queue,
                auth::CredentialsProvider* credentials);

  std::shared_ptr<WatchStream> CreateWatchStream(id<FSTWatchStreamDelegate> delegate) override;
  std::shared_ptr<WriteStream> CreateWriteStream(id<FSTWriteStreamDelegate> delegate) override;

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
  void WriteWatchChange(FSTWatchChange* change, const SnapshotVersion& snap);
  /** Injects a stream failure as though it had come from the backend. */
  void FailWatchStream(NSError* error);

  /** Returns the set of active targets on the watch stream. */
  NSDictionary<FSTBoxedTargetID*, FSTQueryData*>* ActiveTargets() const;
  /** Helper method to expose watch stream state to verify in tests. */
  bool IsWatchStreamOpen() const;

  /**
   * Returns the next write that was "sent to the backend", failing if there are no queued sent
   */
  NSArray<FSTMutation*>* NextSentWrite();
  /** Returns the number of writes that have been sent to the backend but not waited on yet. */
  int WritesSent() const;

  /** Injects a write ack as though it had come from the backend in response to a write. */
  void AckWrite(const SnapshotVersion& version, NSArray<FSTMutationResult*>* results);

  /** Injects a stream failure as though it had come from the backend. */
  void FailWrite(NSError* error);

 private:
  std::shared_ptr<MockWatchStream> watch_stream_;
  std::shared_ptr<MockWriteStream> write_stream_;

  int watch_stream_request_count_ = 0;
  int write_stream_request_count_ = 0;
};
