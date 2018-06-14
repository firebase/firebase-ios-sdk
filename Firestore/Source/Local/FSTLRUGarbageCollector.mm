#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"

#import <queue>

#import "Firestore/Source/Local/FSTMutationQueue.h"
#import "Firestore/Source/Local/FSTPersistence.h"
#import "Firestore/Source/Local/FSTQueryCache.h"
#include "Firestore/core/src/firebase/firestore/util/log.h"

const FSTListenSequenceNumber kFSTListenSequenceNumberInvalid = -1;

class RollingSequenceNumberBuffer {
 public:
  RollingSequenceNumberBuffer(NSUInteger max_elements)
      : max_elements_(max_elements), queue_(std::priority_queue<FSTListenSequenceNumber>()) {
  }

  RollingSequenceNumberBuffer(const RollingSequenceNumberBuffer &other) = delete;
  RollingSequenceNumberBuffer(RollingSequenceNumberBuffer &other) = delete;

  RollingSequenceNumberBuffer &operator=(const RollingSequenceNumberBuffer &other) = delete;
  RollingSequenceNumberBuffer &operator=(RollingSequenceNumberBuffer &other) = delete;

  void AddElement(FSTListenSequenceNumber sequence_number) {
    if (queue_.size() < max_elements_) {
      queue_.push(sequence_number);
    } else {
      FSTListenSequenceNumber highestValue = queue_.top();
      if (sequence_number < highestValue) {
        queue_.pop();
        queue_.push(sequence_number);
      }
    }
  }

  FSTListenSequenceNumber max_value() const {
    return queue_.top();
  }

  std::size_t size() const {
    return queue_.size();
  }

 private:
  std::priority_queue<FSTListenSequenceNumber> queue_;
  const NSUInteger max_elements_;
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

- (NSUInteger)queryCountForPercentile:(NSUInteger)percentile {
  NSUInteger totalCount = (NSUInteger)[self.queryCache count];
  NSUInteger setSize = (NSUInteger)((percentile / 100.0f) * totalCount);
  return setSize;
}

- (FSTListenSequenceNumber)sequenceNumberForQueryCount:(NSUInteger)queryCount {
  if (queryCount == 0) {
    return kFSTListenSequenceNumberInvalid;
  }
  RollingSequenceNumberBuffer buffer(queryCount);
  RollingSequenceNumberBuffer *ptr_to_buffer = &buffer;
  [_delegate enumerateTargetsUsingBlock:^(FSTQueryData *queryData, BOOL *stop) {
    ptr_to_buffer->AddElement(queryData.sequenceNumber);
  }];
  [_delegate enumerateMutationsUsingBlock:^(
                       FSTDocumentKey *docKey, FSTListenSequenceNumber sequenceNumber, BOOL *stop) {
    ptr_to_buffer->AddElement(sequenceNumber);
  }];
  return buffer.max_value();
}

- (NSUInteger)removeQueriesUpThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                                       liveQueries:
                                           (NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries {
  return [_delegate removeTargetsThroughSequenceNumber:sequenceNumber liveQueries:liveQueries];
}

- (NSUInteger)removeOrphanedDocumentsThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber {
  return [_delegate removeOrphanedDocumentsThroughSequenceNumber:sequenceNumber];
}

@end