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

#include <queue>
#include <utility>

#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

using firebase::Timestamp;
using firebase::firestore::local::LruParams;
using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ListenSequenceNumber;

const long kFIRFirestorePersistenceCacheSizeUnlimited = -1;
const ListenSequenceNumber kFSTListenSequenceNumberInvalid = -1;

static long toMilliseconds(const Timestamp &ts) {
  return (1000 * ts.seconds()) + (ts.nanoseconds() / 1000000);
}

static long millisecondsBetween(const Timestamp &start, const Timestamp &end) {
  return toMilliseconds(end) - toMilliseconds(start);
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

/*std::string FSTLruGcResults::ToString() const {
  if (!didRun) {
    return "Garbage Collection skipped";
  } else {
    std::string desc = "LRU Garbage Collection:\n";
    absl::StrAppend(&desc, "\tCounted targets in ", targetCountDurationMs, "ms\n");
    absl::StrAppend(&desc, "\tDetermined least recently used ", sequenceNumbersCollected,
                    " sequence numbers in ", upperBoundDurationMs, "ms\n");
    absl::StrAppend(&desc, "\tRemoved ", targetsRemoved, " targets in ", removedTargetsDurationMs,
                    "ms\n");
    absl::StrAppend(&desc, "\tRemoved ", documentsRemoved, " documents in ",
                    removedDocumentsDurationMs, "ms\n");
    absl::StrAppend(&desc, "\tCompacted leveldb database in ", dbCompactionDurationMs, "ms\n");
    absl::StrAppend(&desc, "Total duration: ", total_duration(), "ms");
    return desc;
  }
}*/

@implementation FSTLRUGarbageCollector {
  id<FSTLRUDelegate> _delegate;
  LruParams _params;
  long _startTime;
  long _lastRunTime;
}

- (instancetype)initWithDelegate:(id<FSTLRUDelegate>)delegate params:(LruParams)params {
  self = [super init];
  if (self) {
    _delegate = delegate;
    _params = std::move(params);
    _lastRunTime = -1;
  }
  return self;
}

- (FSTLruGcResults)collectWithLiveTargets:(NSDictionary<NSNumber *, FSTQueryData *> *)liveTargets {
  if (_params.minBytesThreshold == kFIRFirestorePersistenceCacheSizeUnlimited) {
    LOG_DEBUG("Garbage collection skipped; disabled");
    return FSTLruGcResults::DidNotRun();
  }

  size_t currentSize = [self byteSize];
  if (currentSize < _params.minBytesThreshold) {
    // Not enough on disk to warrant collection. Wait another timeout cycle.
    LOG_DEBUG("Garbage collection skipped; Cache size %i is lower than threshold %i", currentSize, _params.minBytesThreshold);
    return FSTLruGcResults::DidNotRun();
  } else {
    return [self runGCWithLiveTargets:liveTargets];
  }
}

- (FSTLruGcResults)runGCWithLiveTargets:(NSDictionary<NSNumber *, FSTQueryData *> *)liveTargets {
  Timestamp start = Timestamp::Now();
  int sequenceNumbers = [self queryCountForPercentile:_params.percentileToCollect];
  // Cap at the configured max
  if (sequenceNumbers > _params.maximumSequenceNumbersToCollect) {
    sequenceNumbers = _params.maximumSequenceNumbersToCollect;
  }
  Timestamp countedTargets = Timestamp::Now();

  ListenSequenceNumber upperBound = [self sequenceNumberForQueryCount:sequenceNumbers];
  Timestamp foundUpperBound = Timestamp::Now();

  int numTargetsRemoved =
      [self removeQueriesUpThroughSequenceNumber:upperBound liveQueries:liveTargets];
  Timestamp removedTargets = Timestamp::Now();

  int numDocumentsRemoved = [self removeOrphanedDocumentsThroughSequenceNumber:upperBound];
  Timestamp removedDocuments = Timestamp::Now();

  [_delegate runPostCompaction];
  Timestamp compactedDb = Timestamp::Now();

  long total_duration = millisecondsBetween(start, compactedDb);
  std::string desc = "LRU Garbage Collection:\n";
  absl::StrAppend(&desc, "\tCounted targets in ", millisecondsBetween(start, countedTargets), "ms\n");
  absl::StrAppend(&desc, "\tDetermined least recently used ", sequenceNumbers,
          " sequence numbers in ", millisecondsBetween(countedTargets, foundUpperBound), "ms\n");
  absl::StrAppend(&desc, "\tRemoved ", numTargetsRemoved, " targets in ", millisecondsBetween(foundUpperBound, removedTargets),
          "ms\n");
  absl::StrAppend(&desc, "\tRemoved ", numDocumentsRemoved, " documents in ",
          millisecondsBetween(removedTargets, removedDocuments), "ms\n");
  absl::StrAppend(&desc, "\tCompacted leveldb database in ", millisecondsBetween(removedDocuments, compactedDb), "ms\n");
  absl::StrAppend(&desc, "Total duration: ", total_duration, "ms");
  LOG_DEBUG(desc.c_str());

  return FSTLruGcResults{
      YES,
      sequenceNumbers,
      numTargetsRemoved,
      numDocumentsRemoved};
}

- (int)queryCountForPercentile:(NSUInteger)percentile {
  int totalCount = [_delegate targetCount];
  int setSize = (int)((percentile / 100.0f) * totalCount);
  return setSize;
}

- (ListenSequenceNumber)sequenceNumberForQueryCount:(NSUInteger)queryCount {
  if (queryCount == 0) {
    return kFSTListenSequenceNumberInvalid;
  }
  RollingSequenceNumberBuffer buffer(queryCount);
  // Pointer is necessary to access stack-allocated buffer from a block.
  RollingSequenceNumberBuffer *ptr_to_buffer = &buffer;
  [_delegate enumerateTargetsUsingBlock:^(FSTQueryData *queryData, BOOL *stop) {
    ptr_to_buffer->AddElement(queryData.sequenceNumber);
  }];
  [_delegate enumerateMutationsUsingBlock:^(const DocumentKey &docKey,
                                            ListenSequenceNumber sequenceNumber, BOOL *stop) {
    ptr_to_buffer->AddElement(sequenceNumber);
  }];
  return buffer.max_value();
}

- (int)removeQueriesUpThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber
                                liveQueries:
                                    (NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  return [_delegate removeTargetsThroughSequenceNumber:sequenceNumber liveQueries:liveQueries];
}

- (int)removeOrphanedDocumentsThroughSequenceNumber:(ListenSequenceNumber)sequenceNumber {
  return [_delegate removeOrphanedDocumentsThroughSequenceNumber:sequenceNumber];
}

- (size_t)byteSize {
  return [_delegate byteSize];
}

@end
