//
//  FIRVectorQuerySnapshot.h
//  FirebaseFirestoreInternal
//
//  Created by Mark Duckworth on 7/25/24.
//
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class FIRVectorQuery;
@class FIRAggregateQuery;
@class FIRAggregateField;
@class FIRFieldPath;
@class FIRFirestore;
@class FIRFilter;
@class FIRQuerySnapshot;
@class FIRDocumentSnapshot;

NS_SWIFT_NAME(VectorQuerySnapshot)
@interface FIRVectorQuerySnapshot : NSObject
@property(nonatomic, strong, readonly) FIRVectorQuery *query;
@property(nonatomic, strong, readonly) FIRSnapshotMetadata *metadata;
@property(nonatomic, readonly, getter=isEmpty) BOOL empty;
@property(nonatomic, readonly) NSInteger count;
@property(nonatomic, strong, readonly) NSArray<FIRQueryDocumentSnapshot *> *documents;
@property(nonatomic, strong, readonly) NSArray<FIRDocumentChange *> *documentChanges;
- (NSArray<FIRDocumentChange *> *)documentChangesWithIncludeMetadataChanges:
    (BOOL)includeMetadataChanges NS_SWIFT_NAME(documentChanges(includeMetadataChanges:));

@end

NS_ASSUME_NONNULL_END
