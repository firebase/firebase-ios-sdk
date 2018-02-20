#import <Foundation/Foundation.h>

#import "Firestore/Source/Model/FSTDocumentKeySet.h"

@protocol FSTDataAccess <NSObject>

- (FSTTargetID)highestTargetID;

- (FSTSnapshotVersion *)lastRemoteSnapshotVersion;

- (FSTQueryData *)queryDataForQuery:(FSTQuery *)query;

- (FSTDocumentKeySet *)documentsForTarget:(FSTTargetID)targetID;

- (FSTDocumentDictionary *)documentsMatchingQuery:(FSTQuery *)query;

- (nullable FSTMaybeDocument *)documentForKey:(FSTDocumentKey *)documentKey;

@end

@protocol FSTDataCache <FSTDataAccess>

//@property(nonatomic, strong) FSTListenSequence *listenSequence;

- (void)start;

- (void)shutdown;

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

@end