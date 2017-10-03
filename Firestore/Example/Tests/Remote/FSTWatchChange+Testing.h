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

#import "Core/FSTTypes.h"
#import "Remote/FSTWatchChange.h"

NS_ASSUME_NONNULL_BEGIN

/** FSTWatchTargetChange is a change to a watch target. */
@interface FSTWatchTargetChange (Testing)

+ (instancetype)changeWithState:(FSTWatchTargetChangeState)state
                      targetIDs:(NSArray<NSNumber *> *)targetIDs;

+ (instancetype)changeWithState:(FSTWatchTargetChangeState)state
                      targetIDs:(NSArray<NSNumber *> *)targetIDs
                          cause:(nullable NSError *)cause;

+ (instancetype)changeWithState:(FSTWatchTargetChangeState)state
                      targetIDs:(NSArray<NSNumber *> *)targetIDs
                    resumeToken:(nullable NSData *)resumeToken;

@end

NS_ASSUME_NONNULL_END
