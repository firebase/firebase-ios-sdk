/*
 * Copyright 2017 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "FIRDocumentSnapshot.h"

#import "FIRDocumentSnapshot+Internal.h"
#import "FSTAssert.h"
#import "Firestore/Source/API/FIRDocumentReference+Internal.h"
#import "Firestore/Source/API/FIRFieldPath+Internal.h"
#import "Firestore/Source/API/FIRFirestore+Internal.h"
#import "Firestore/Source/API/FIRSnapshotMetadata+Internal.h"
#import "Firestore/Source/API/FIRSnapshotOptions+Internal.h"
#import "Firestore/Source/Model/FSTDatabaseID.h"
#import "Firestore/Source/Model/FSTDocument.h"
#import "Firestore/Source/Model/FSTDocumentKey.h"
#import "Firestore/Source/Model/FSTFieldValue.h"
#import "Firestore/Source/Model/FSTPath.h"
#import "Firestore/Source/Util/FSTUsageValidation.h"

NS_ASSUME_NONNULL_BEGIN

/** The default server timestamp behavior (returning NSNull for pending timestamps). */
static const int kFIRServerTimestampBehaviorDefault = -1;

@interface FIRSnapshotOptions ()

@property(nonatomic) int serverTimestampBehavior;

@end

@implementation FIRSnapshotOptions

- (instancetype)initWithServerTimestampBehavior:(int)serverTimestampBehavior {
  self = [super init];

  if (self) {
    _serverTimestampBehavior = serverTimestampBehavior;
  }

  return self;
}

+ (instancetype)defaultOptions {
  static FIRSnapshotOptions *sharedInstance = nil;
  static dispatch_once_t onceToken;

  dispatch_once(&onceToken, ^{
    sharedInstance = [[FIRSnapshotOptions alloc]
        initWithServerTimestampBehavior:kFIRServerTimestampBehaviorDefault];
  });

  return sharedInstance;
}

+ (instancetype)setServerTimestampBehavior:(FIRServerTimestampBehavior)serverTimestampBehavior {
  switch (serverTimestampBehavior) {
    case FIRServerTimestampBehaviorEstimate:
      return [[FIRSnapshotOptions alloc]
          initWithServerTimestampBehavior:FIRServerTimestampBehaviorEstimate];
    case FIRServerTimestampBehaviorPrevious:
      return [[FIRSnapshotOptions alloc]
          initWithServerTimestampBehavior:FIRServerTimestampBehaviorPrevious];
    default:
      FSTFail(@"Encountered unknown server timestamp behavior: %d", (int)serverTimestampBehavior);
  }
}

@end

NS_ASSUME_NONNULL_END