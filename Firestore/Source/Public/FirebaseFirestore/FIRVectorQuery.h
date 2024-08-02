//
//  FIRVectorQuery.h
//  FirebaseFirestoreInternal
//
//  Created by Mark Duckworth on 7/25/24.
//
#import <Foundation/Foundation.h>

#import "FIRFirestoreVectorSource.h"
#import "FIRVectorQuerySnapshot.h"

@class FIRAggregateQuery;
@class FIRAggregateField;
@class FIRFieldPath;
@class FIRFirestore;
@class FIRFilter;
@class FIRVectorQuerySnapshot;
@class FIRDocumentSnapshot;
@class FIRVectorQuery;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(VectorQuery)
@interface FIRVectorQuery : NSObject

@property(nonatomic, strong, readonly) FIRQuery *query;

/**
 * Executes this query.
 *
 * @param source The source from which to acquire the VectorQuery results.
 * @param completion a block to execute once the results have been successfully read.
 *     snapshot will be `nil` only if error is `non-nil`.
 */
- (void)getDocumentsWithSource:(FIRFirestoreVectorSource)source
                   completion:(void (^)(FIRVectorQuerySnapshot *_Nullable snapshot,
                                        NSError *_Nullable error))completion
    NS_SWIFT_NAME(getDocuments(source:completion:));

@end

NS_ASSUME_NONNULL_END
