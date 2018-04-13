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

#import "Firestore/Source/Core/FSTTargetIDGenerator.h"

#import <libkern/OSAtomic.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - FSTTargetIDGenerator

static const int kReservedBits = 1;

/** FSTTargetIDGeneratorID is the set of all valid generators. */
typedef NS_ENUM(NSInteger, FSTTargetIDGeneratorID) {
  FSTTargetIDGeneratorIDLocalStore = 0,
  FSTTargetIDGeneratorIDSyncEngine = 1
};

@interface FSTTargetIDGenerator () {
  // This is volatile so it can be used with OSAtomicAdd32.
  volatile FSTTargetID _previousID;
}

/**
 * Initializes the generator.
 *
 * @param generatorID A unique ID indicating which generator this is.
 * @param after Every call to nextID will return a number > @a after.
 */
- (instancetype)initWithGeneratorID:(FSTTargetIDGeneratorID)generatorID
                    startingAfterID:(FSTTargetID)after NS_DESIGNATED_INITIALIZER;

// This is typed as FSTTargetID because we need to do bitwise operations with them together.
@property(nonatomic, assign) FSTTargetID generatorID;
@end

@implementation FSTTargetIDGenerator

#pragma mark - Constructors

- (instancetype)initWithGeneratorID:(FSTTargetIDGeneratorID)generatorID
                    startingAfterID:(FSTTargetID)after {
  self = [super init];
  if (self) {
    _generatorID = generatorID;

    // Replace the generator part of |after| with this generator's ID.
    FSTTargetID afterWithoutGenerator = (after >> kReservedBits) << kReservedBits;
    FSTTargetID afterGenerator = after - afterWithoutGenerator;
    if (afterGenerator >= _generatorID) {
      // For example, if:
      //   self.generatorID = 0b0000
      //   after = 0b1011
      //   afterGenerator = 0b0001
      // Then:
      //   previous = 0b1010
      //   next = 0b1100
      _previousID = afterWithoutGenerator | self.generatorID;
    } else {
      // For example, if:
      //   self.generatorID = 0b0001
      //   after = 0b1010
      //   afterGenerator = 0b0000
      // Then:
      //   previous = 0b1001
      //   next = 0b1011
      _previousID = (afterWithoutGenerator | self.generatorID) - (1 << kReservedBits);
    }
  }
  return self;
}

+ (instancetype)generatorForLocalStoreStartingAfterID:(FSTTargetID)after {
  return [[FSTTargetIDGenerator alloc] initWithGeneratorID:FSTTargetIDGeneratorIDLocalStore
                                           startingAfterID:after];
}

+ (instancetype)generatorForSyncEngineStartingAfterID:(FSTTargetID)after {
  return [[FSTTargetIDGenerator alloc] initWithGeneratorID:FSTTargetIDGeneratorIDSyncEngine
                                           startingAfterID:after];
}

#pragma mark - Public methods

- (FSTTargetID)nextID {
  return OSAtomicAdd32(1 << kReservedBits, &_previousID);
}

@end

NS_ASSUME_NONNULL_END
