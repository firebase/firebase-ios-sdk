#import <Foundation/Foundation.h>

#import "Firestore/Source/Core/FSTTypes.h"

@protocol FSTQueryCache;

const FSTListenSequenceNumber kFSTListenSequenceNumberInvalid = -1;

@interface FSTLruGarbageCollector : NSObject

- (instancetype)initWithQueryCache:(id<FSTQueryCache>)queryCache;

- (NSUInteger)queryCountForPercentile:(NSUInteger)percentile;

- (FSTListenSequenceNumber)sequenceNumberForQueryCount:(NSUInteger)queryCount;
@end