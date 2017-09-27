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

#import "FSTWatchChange+Testing.h"

#import "Model/FSTDocument.h"
#import "Remote/FSTWatchChange.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTWatchTargetChange (Testing)

+ (instancetype)changeWithState:(FSTWatchTargetChangeState)state
                      targetIDs:(NSArray<NSNumber *> *)targetIDs {
  return [[FSTWatchTargetChange alloc] initWithState:state
                                           targetIDs:targetIDs
                                         resumeToken:[NSData data]
                                               cause:nil];
}

+ (instancetype)changeWithState:(FSTWatchTargetChangeState)state
                      targetIDs:(NSArray<NSNumber *> *)targetIDs
                          cause:(nullable NSError *)cause {
  return [[FSTWatchTargetChange alloc] initWithState:state
                                           targetIDs:targetIDs
                                         resumeToken:[NSData data]
                                               cause:cause];
}

+ (instancetype)changeWithState:(FSTWatchTargetChangeState)state
                      targetIDs:(NSArray<NSNumber *> *)targetIDs
                    resumeToken:(nullable NSData *)resumeToken {
  return [[FSTWatchTargetChange alloc] initWithState:state
                                           targetIDs:targetIDs
                                         resumeToken:resumeToken
                                               cause:nil];
}

@end

NS_ASSUME_NONNULL_END
