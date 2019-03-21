/*
 * Copyright 2018 Google
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

#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"

#include <chrono>  //NOLINT(build/c++11)
#include <queue>
#include <utility>

#import "Firestore/Source/Local/FSTPersistence.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

using Millis = std::chrono::milliseconds;
using firebase::Timestamp;
using firebase::firestore::local::LruParams;
using firebase::firestore::local::LruResults;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ListenSequenceNumber;
using firebase::firestore::model::TargetId;

const int64_t kFIRFirestoreCacheSizeUnlimited = LruParams::CacheSizeUnlimited;
const ListenSequenceNumber kFSTListenSequenceNumberInvalid = -1;

static Millis::rep millisecondsBetween(const Timestamp &start, const Timestamp &end) {
  return std::chrono::duration_cast<Millis>(end.ToTimePoint() - start.ToTimePoint()).count();
}

/**
 * RollingSequenceNumberBuffer tracks the nth sequence number in a series. Sequence numbers may be
 * added out of order.
 */
class RollingSequenceNumberBuffer {
 public:
  explicit RollingSequenceNumberBuffer(size_t max_elements)
      : queue_(std::priority_queue<ListenSequenceNumber>()), max_elements_(max_elements) {
  }

  RollingSequenceNumberBuffer(const RollingSequenceNumberBuffer &other) = delete;

  RollingSequenceNumberBuffer &operator=(const RollingSequenceNumberBuffer &other) = delete;

  void AddElement(ListenSequenceNumber sequence_number) {
    if (queue_.size() < max_elements_) {
      queue_.push(sequence_number);
    } else {
      ListenSequenceNumber highestValue = queue_.top();
      if (sequence_number < highestValue) {
        queue_.pop();
        queue_.push(sequence_number);
      }
    }
  }

  ListenSequenceNumber max_value() const {
    return queue_.top();
  }

  size_t size() const {
    return queue_.size();
  }

 private:
  std::priority_queue<ListenSequenceNumber> queue_;
  const size_t max_elements_;
};

@implementation FSTLRUGarbageCollector {
  __weak id<FSTLRUDelegate> _delegate;
  LruParams _params;
}

- (instancetype)initWithDelegate:(id<FSTLRUDelegate>)delegate params:(LruParams)params {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _params = std::move(params);
  }
  return self;
}

- (LruResults)collectWithLiveTargets:
    (const std::unordered_map<TargetId, FSTQueryData *> &)liveTargets {
  if (_params.minBytesThreshold == kFIRFirestoreCacheSizeUnlimited) {
    LOG_DEBUG("Garbage collection skipped; disabled");
    return LruResults::DidNotRun();
  }

  size_t currentSize = [self byteSize];
  if (currentSize < _params.minBytesThreshold) {
    // Not enough on disk to warrant collection. Wait another timeout cycle.
    LOG_DEBUG("Garbage collection skipped; Cache size %s is lower than threshold %s", currentSize,
              _params.minBytesThreshold);
    return LruResults::DidNotRun();
  } else {
    LOG_DEBUG("Running garbage collection on cache of size: %s", currentSize);
    return [self runGCWithLiveTargets:liveTargets];
  }
}

- (LruResults)runGCWithLiveTargets:
    (const std::unordered_map<TargetId, FSTQueryData *> &)liveTargets {
  Timestamp start = Timestamp::Now();
  int sequenceNumbers = [self queryCountForPercentile:_params.percentileToCollect];
  // Cap at the configured max
  if (sequenceNumbers > _params.maximumSequenceNumbersToCollect) {
    sequenceNumbers = _params.maximumSequenceNumbersToCollect;
  }
  Timestamp countedTargets = Timestamp::Now();

  ListenSequenceNumber upperBound = [self sequenceNumberForQueryCount:sequenceNumbers];
  Timestamp foundUpperBound = Timestamp::Now();

  int numTargetsRemoved = [self removeQueriesUpThroughSequenceNumber:upperBound
                                                         liveQueries:liveTargets];
  Timestamp removedTargets = Timestamp::Now();

  int numDocumentsRemoved = [self removeOrphanedDocumentsThroughSequenceNumber:upperBound];
  Timestamp removedDocuments = Timestamp::Now();

  std::string desc = "LRU Garbage Collection:\n";
  absl::StrAppend(&desc, "\tCounted targets in ", millisecondsBetween(start, countedTargets),
                  "ms\n");
  absl::StrAppend(&desc, "\tDetermined least recently used ", sequenceNumbers,
                  " sequence numbers in ", millisecondsBetween(countedTargets, foundUpperBound),
                  "ms\n");
  absl::StrAppend(&desc, "\tRemoved ", numTargetsRemoved, " targets in ",
                  millisecondsBetween(foundUpperBound, removedTargets), "ms\n");
  absl::StrAppend(&desc, "\tRemoved ", numDocumentsRemoved, " documents in ",
                  millisecondsBetween(removedTargets, removedDocuments), "ms\n");
  absl::StrAppend(&desc, "Total duration: ", millisecondsBetween(start, removedDocuments), "ms");
  LOG_DEBUG(desc.c_str());

  return LruResults{/* didRun= */ true, sequenceNumbers, numTargetsRemoved, numDocumentsRemoved};
}

- (int)queryCountForPercentile:(NSUInteger)percentile {
  size_t totalCount = [_delegate sequenceNumberCount];
  int setSize = (int)((percentile / 100.0f) * totalCount);
  return setSize;
}

- (ListenSequenceNumber)sequenceNumberForQueryCount:(NSUInteger)queryCount {
  if (queryCount == 0) {
    return kFSTListenSequenceNumberInvalid;
  }
  RollingSequenceNumberBuffer buffer(queryCount);

  [_delegate enumerateTargetsUsingCallback:[&buffer](FSTQueryData *queryData) {
    buffer.AddElement(queryData.sequenceNumber);
  }];
  [_delegate enumerateMutationsUsingCallback:[&buffer](const DocumentKey &docKey,
                                                       ListenSequenceNumber sequenceNumber) {
    buffer.AddElement(sequenceNumber);
  }];
  return buffer.max_value();
}

- (int)removeQueriesUpThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                                liveQueries:(const std::unordered_map<TargetId, FSTQueryData *> &)
                                                liveQueries {
  return [_delegate removeTargetsThroughSequenceNumber:sequenceNumber liveQueries:liveQueries];
}

- (int)removeOrphanedDocumentsThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber {
  return [_delegate removeOrphanedDocumentsThroughSequenceNumber:sequenceNumber];
}

- (size_t)byteSize {
  return [_delegate byteSize];
}

@end
