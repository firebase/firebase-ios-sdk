//
//  FIRFirestoreDistanceMeasure.h
//  FirebaseFirestoreInternal
//
//  Created by Mark Duckworth on 7/25/24.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FIRFirestoreDistanceMeasure) {
  FIRFirestoreDistanceMeasureCosine,
  FIRFirestoreDistanceMeasureEuclidean,
  FIRFirestoreDistanceMeasureDotProduct
} NS_SWIFT_NAME(FirestoreDistanceMeasure);
