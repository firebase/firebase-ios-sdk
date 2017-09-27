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

#import "FSTNoOpGarbageCollector.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTNoOpGarbageCollector

- (BOOL)isEager {
  return NO;
}

- (void)addGarbageSource:(id<FSTGarbageSource>)garbageSource {
  // Not tracking garbage so don't track sources.
}

- (void)removeGarbageSource:(id<FSTGarbageSource>)garbageSource {
  // Not tracking garbage so don't track sources.
}

- (void)addPotentialGarbageKey:(FSTDocumentKey *)key {
  // Not tracking garbage so ignore.
}

- (NSSet<FSTDocumentKey *> *)collectGarbage {
  return [NSSet set];
}

@end

NS_ASSUME_NONNULL_END
