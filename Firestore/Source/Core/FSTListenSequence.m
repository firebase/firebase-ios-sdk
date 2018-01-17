#import "FSTListenSequence.h"

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTListenSequence

@interface FSTListenSequence () {
  FSTListenSequenceNumber _previousSequenceNumber;
}

@end

@implementation FSTListenSequence

#pragma mark - Constructors

- (instancetype)initStartingAfter:(FSTListenSequenceNumber)after {
  self = [super init];
  if (self) {
    _previousSequenceNumber = after;
  }
  return self;
}

#pragma mark - Public methods

- (FSTListenSequenceNumber)next {
  _previousSequenceNumber++;
  return _previousSequenceNumber;
}

@end

NS_ASSUME_NONNULL_END