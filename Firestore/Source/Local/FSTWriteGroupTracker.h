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

@class FSTWriteGroup;

NS_ASSUME_NONNULL_BEGIN

/**
 * Helper class for FSTPersistence implementations to create WriteGroups and verify internal
 * contracts are maintained:
 * 1. Can't create a group when an uncommitted group exists (no nesting).
 * 2. Can't commit a group that differs from the last created one.
 */
@interface FSTWriteGroupTracker : NSObject

/** Creates and returns an FSTWriteGroupTracker instance. */
+ (instancetype)tracker;

/**
 * Verifies there's no active group already and then creates a new group and stores it for later
 * validation with `endGroup`.
 */
- (FSTWriteGroup *)startGroupWithAction:(NSString *)action;

/** Ends a group previously started with `startGroupWithAction`. */
- (void)endGroup:(FSTWriteGroup *)group;

@end

NS_ASSUME_NONNULL_END
