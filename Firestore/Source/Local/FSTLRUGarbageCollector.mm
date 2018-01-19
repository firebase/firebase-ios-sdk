#import <memory>
#import <queue>
#import "Firestore/Source/Local/FSTLRUGarbageCollector.h"

#import "Firestore/Source/Local/FSTQueryCache.h"
#import "Firestore/Source/Local/FSTQueryData.h"

using std::priority_queue;

class RollingSequenceNumberBuffer {
 public:
  RollingSequenceNumberBuffer(NSUInteger max_elements) : max_elements_(max_elements) {
    queue_ = std::make_unique<priority_queue<FSTListenSequenceNumber> >();
  }

  RollingSequenceNumberBuffer(const RollingSequenceNumberBuffer& other) = delete;
  RollingSequenceNumberBuffer(RollingSequenceNumberBuffer& other) = delete;

  RollingSequenceNumberBuffer& operator=(const RollingSequenceNumberBuffer& other) = delete;
  RollingSequenceNumberBuffer& operator=(RollingSequenceNumberBuffer& other) = delete;

  void AddElement(FSTListenSequenceNumber sequence_number) {
    if (queue_->size() < max_elements_) {
      queue_->push(sequence_number);
    } else {
      FSTListenSequenceNumber highestValue = queue_->top();
      if (sequence_number < highestValue) {
        queue_->pop();
        queue_->push(sequence_number);
      }
    }
  }

  FSTListenSequenceNumber max_value() const {
    return queue_->top();
  }

  std::size_t size() const {
    return queue_->size();
  }

 private:
  std::unique_ptr<priority_queue<FSTListenSequenceNumber> > queue_;
  const NSUInteger max_elements_;
};

@interface FSTLRUGarbageCollector ()

@property (nonatomic, strong, readonly) id <FSTQueryCache> queryCache;

@end

@implementation FSTLRUGarbageCollector {
}

- (instancetype)initWithQueryCache:(id <FSTQueryCache>)queryCache {
  self = [super init];
  if (self) {
    _queryCache = queryCache;
  }
  return self;
}

- (NSUInteger)queryCountForPercentile:(NSUInteger)percentile {
  NSUInteger totalCount = [self.queryCache count];
  NSUInteger setSize = (NSUInteger)((percentile / 100.0f) * totalCount);
  return setSize;
}

- (FSTListenSequenceNumber)sequenceNumberForQueryCount:(NSUInteger)queryCount {
  if (queryCount == 0) {
    return kFSTListenSequenceNumberInvalid;
  }
  RollingSequenceNumberBuffer buffer(queryCount);
  RollingSequenceNumberBuffer* ptr_to_buffer = &buffer;
  [self.queryCache enumerateQueryDataUsingBlock:^(FSTQueryData *queryData, BOOL *stop){
    ptr_to_buffer->AddElement(queryData.sequenceNumber);
  }];
  return buffer.max_value();
}

- (NSUInteger)removeQueriesUpThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                                       liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries
                                             group:(FSTWriteGroup *)group {
  __block NSUInteger count = 0;
  [self.queryCache enumerateQueryDataUsingBlock:^(FSTQueryData *queryData, BOOL *stop) {
    if (queryData.sequenceNumber <= sequenceNumber) {
      if (liveQueries[@(queryData.targetID)] == nil) {
        [self.queryCache removeQueryData:queryData group:group];
        count++;
      }
    }
  }];
  return count;
}

@end