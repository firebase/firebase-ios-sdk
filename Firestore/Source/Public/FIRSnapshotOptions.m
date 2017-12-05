//
// Created by Sebastian Schmidt on 12/4/17.
//

#import "FIRDocumentSnapshot.h"
#import "FIRSnapshotOptions+Internal.h"
#import "FSTUsageValidation.h"

@implementation FIRSnapshotOptions (Internal)

FSTServerTimestampBehavior _serverTimestampBehavior;

- (instancetype)initWithServerTimestampBehavior:
    (FSTServerTimestampBehavior)serverTimestampBehavior {
  self = [super init];
  if (self) {
    _serverTimestampBehavior = serverTimestampBehavior;
  }
  return self;
}

 - (FSTServerTimestampBehavior)serverTimestampBehavior {
   return _serverTimestampBehavior;
 }

@end


@implementation FIRSnapshotOptions

+ (instancetype)setServerTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior {
  if (serverTimestampBehavior == FIRServerTimestampBehaviorEstimate) {
    return [[FIRSnapshotOptions alloc]
        initWithServerTimestampBehavior:FSTServerTimestampBehaviorEstimate];
  } else if (serverTimestampBehavior == FIRServerTimestampBehaviorPrevious) {
    return [[FIRSnapshotOptions alloc]
        initWithServerTimestampBehavior:FSTServerTimestampBehaviorPrevious];
  } else {
    FSTThrowInvalidArgument(@"Unexpected value found for FIRServerTimestampBehavior.");
  }
}

@end
