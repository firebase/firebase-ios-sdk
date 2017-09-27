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

#import <Foundation/Foundation.h>

#import "FSTTypes.h"

NS_ASSUME_NONNULL_BEGIN

/**
 * FSTTargetIDGenerator generates monotonically increasing integer IDs. There are separate
 * generators for different scopes. While these generators will operate independently of each
 * other, they are scoped, such that no two generators will ever produce the same ID. This is
 * useful, because sometimes the backend may group IDs from separate parts of the client into the
 * same ID space.
 */
@interface FSTTargetIDGenerator : NSObject

/**
 * Creates and returns the FSTTargetIDGenerator for the local store.
 *
 * @param after An ID to start at. Every call to nextID will return an ID > @a after.
 * @return A shared instance of FSTTargetIDGenerator.
 */
+ (instancetype)generatorForLocalStoreStartingAfterID:(FSTTargetID)after;

/**
 * Creates and returns the FSTTargetIDGenerator for the sync engine.
 *
 * @param after An ID to start at. Every call to nextID will return an ID > @a after.
 * @return A shared instance of FSTTargetIDGenerator.
 */
+ (instancetype)generatorForSyncEngineStartingAfterID:(FSTTargetID)after;

- (id)init __attribute__((unavailable("Use a static constructor method.")));

/** Returns the next ID in the sequence. */
- (FSTTargetID)nextID;

@end

NS_ASSUME_NONNULL_END
