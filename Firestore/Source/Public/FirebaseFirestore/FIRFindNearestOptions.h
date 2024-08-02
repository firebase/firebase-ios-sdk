//
//  FIRFindNearestOptions.h
//  FirebaseFirestoreInternal
//
//  Created by Mark Duckworth on 7/25/24.
//
#import <Foundation/Foundation.h>

#import "FIRFieldPath.h"

@class FIRAggregateQuery;
@class FIRAggregateField;
@class FIRFieldPath;
@class FIRFirestore;
@class FIRFilter;
@class FIRQuerySnapshot;
@class FIRDocumentSnapshot;
@class FIRVectorQuery;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(FindNearestOptions)
@interface FIRFindNearestOptions : NSObject
@property (nonatomic, readonly) FIRFieldPath *distanceResultFieldPath;
@property (nonatomic, readonly) NSNumber *distanceThreshold;

- (nonnull instancetype)init NS_DESIGNATED_INITIALIZER;

- (nonnull FIRFindNearestOptions *)optionsWithDistanceResultField:
    (NSString *)distanceResultField;

- (nonnull FIRFindNearestOptions *)optionsWithDistanceResultFieldPath:
    (FIRFieldPath *)distanceResultFieldPath;

- (nonnull FIRFindNearestOptions *)optionsWithDistanceThreshold:
    (NSNumber *)distanceThreshold;

@end


NS_ASSUME_NONNULL_END
