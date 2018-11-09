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

#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#include "Firestore/core/src/firebase/firestore/model/document_key.h"

using firebase::firestore::model::DocumentKey;
using firebase::firestore::model::ListenSequenceNumber;

const ListenSequenceNumber kFSTListenSequenceNumberInvalid = -1;

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

@interface FSTLRUGarbageCollector ()

@property(nonatomic, strong, readonly) id<FSTQueryCache> queryCache;

@end

@implementation FSTLRUGarbageCollector {
  id<FSTLRUDelegate> _delegate;
}

- (instancetype)initWithQueryCache:(id<FSTQueryCache>)queryCache
                          delegate:(id<FSTLRUDelegate>)delegate {
  self = [super init];
  if (self) {
    _queryCache = queryCache;
    _delegate = delegate;
  }
  return self;
}

- (int)queryCountForPercentile:(NSUInteger)percentile {
  int totalCount = [self.queryCache count];
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
