#import <Foundation/Foundation.h>

#import "Firestore/Source/Core/FSTTypes.h"
#import "Firestore/Source/Model/FSTDocumentDictionary.h"
#import "Firestore/Source/Model/FSTDocumentKeySet.h"

@class FSTQuery;
@class FSTQueryData;
@class FSTSnapshotVersion;
@class FSTRemoteDocumentChangeBuffer;
@class FSTTargetChange;
@class FSTUser;
@class FSTWriteGroup;
@protocol FSTPersistence;
@protocol FSTPersistenceCleanupDelegate;
@protocol FSTMutationQueue;

NS_ASSUME_NONNULL_BEGIN

@interface FSTEagerDataAccess : NSObject<FSTPersistenceCleanupDelegate>

+ (FSTEagerDataAccess *)delegate;

@end

@interface FSTLRUDataAccess : NSObject<FSTPersistenceCleanupDelegate>

// TODO(GC): include tuning values and access to schedule a callback in the future
+ (FSTLRUDataAccess *)delegate;

@end

// More limited access to underlying tables for components that just need to read
@protocol FSTDataAccess <NSObject>

- (FSTTargetID)highestTargetID;

- (FSTSnapshotVersion *)lastRemoteSnapshotVersion;

- (FSTQueryData *)queryDataForQuery:(FSTQuery *)query;

- (FSTDocumentKeySet *)documentsForTarget:(FSTTargetID)targetID;

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query;

- (nullable FSTMaybeDocument *)documentForKey:(FSTDocumentKey *)documentKey;

@end

// Access to mutate underlying persistence tables.
// TODO: better name
@interface FSTDataCache : NSObject<FSTDataAccess>

// This is not in the read-only portion since this gives direct access to write to
// the mutation queue, as well as read it.
@property (strong, nonatomic, readonly) id<FSTMutationQueue> mutationQueue;

+ (FSTDataCache *)cacheWithPersistence:(id<FSTPersistence>)persistence
                       cleanupDelegate:(id<FSTPersistenceCleanupDelegate>)delegate;

- (void)start;

- (void)shutdown;

- (void)userDidChange:(FSTUser *)user;

- (FSTQueryData *)updateQuery:(FSTTargetID)targetID forChange:(FSTTargetChange *)change group:(FSTWriteGroup *)group;

- (void)resetQuery:(FSTQueryData *)queryData documents:(FSTDocumentKeySet *)documents group:(FSTWriteGroup *)group;

- (void)updateQuery:(FSTQueryData *)queryData
     documentsAdded:(FSTDocumentKeySet *)added
   documentsRemoved:(FSTDocumentKeySet *)removed
              group:(FSTWriteGroup *)group;

- (FSTRemoteDocumentChangeBuffer *)changeBuffer;

- (void)addPotentiallyOrphanedDocuments:(FSTDocumentKeySet *)affected
                                  group:(FSTWriteGroup *)group;

- (void)addNewSnapshotVersion:(FSTSnapshotVersion *)version group:(FSTWriteGroup *)group;

- (FSTQueryData *)getOrCreateQueryData:(FSTQuery *)query;

- (FSTQueryData *)removeQuery:(FSTQuery *)query group:(FSTWriteGroup *)group;

- (FSTWriteGroup *)groupWithAction:(NSString *)action;

- (void)commitGroup:(FSTWriteGroup *)group;

@end

NS_ASSUME_NONNULL_END