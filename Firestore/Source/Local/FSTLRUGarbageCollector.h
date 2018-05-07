#import <Foundation/Foundation.h>

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Local/FSTQueryData.h"
#import "Firestore/Source/Local/FSTRemoteDocumentCache.h"

@protocol FSTMutationQueue;
@protocol FSTPersistence;
@protocol FSTQueryCache;

@class FSTLRUGarbageCollector;

extern const FSTListenSequenceNumber kFSTListenSequenceNumberInvalid;

@protocol FSTLRUDelegate

- (void)enumerateTargetsUsingBlock:(void (^)(FSTQueryData *queryData, BOOL *stop))block;

- (void)enumerateMutationsUsingBlock:(void (^)(FSTDocumentKey *key, FSTListenSequenceNumber sequenceNumber, BOOL *stop))block;

- (NSUInteger)removeOrphanedDocumentsThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber;

- (NSUInteger)removeQueriesThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber liveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries;

@property(strong, nonatomic, readonly) FSTLRUGarbageCollector *gc;

@end

@interface FSTLRUGarbageCollector : NSObject

- (instancetype)initWithQueryCache:(id<FSTQueryCache>)queryCache
                          delegate:(id<FSTLRUDelegate>)delegate;

- (NSUInteger)queryCountForPercentile:(NSUInteger)percentile;

- (FSTListenSequenceNumber)sequenceNumberForQueryCount:(NSUInteger)queryCount;

- (NSUInteger)removeQueriesUpThroughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                                       liveQueries:
                                           (NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries;

- (NSUInteger)removeOrphanedDocuments:(id<FSTRemoteDocumentCache>)remoteDocumentCache
                throughSequenceNumber:(FSTListenSequenceNumber)sequenceNumber
                        mutationQueue:(id<FSTMutationQueue>)mutationQueue;

- (void)collectGarbageWithLiveQueries:(NSDictionary<NSNumber *, FSTQueryData *> *)liveQueries
                        documentCache:(id<FSTRemoteDocumentCache>)docCache
                        mutationQueue:(id<FSTMutationQueue>)mutationQueue
                           percentile:(NSUInteger)percentileToGC;

@end