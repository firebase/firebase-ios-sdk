//
//  FIRFirestoreDistanceMeasure.h
//  FirebaseFirestoreInternal
//
//  Created by Mark Duckworth on 7/25/24.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, FIRDistanceMeasure) {
  FIRDistanceMeasureCosine,
  FIRDistanceMeasureEuclidean,
  FIRDistanceMeasureDotProduct
} NS_SWIFT_NAME(FirestoreDistanceMeasure);
