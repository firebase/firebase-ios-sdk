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

#import "FirebaseDatabase/Tests/Helpers/FTestCachePolicy.h"

@interface FTestCachePolicy ()

@property(nonatomic) float percentOfQueries;
@property(nonatomic) NSUInteger maxTrackedQueries;
@property(nonatomic) BOOL pruneNext;

@end

@implementation FTestCachePolicy

- (id)initWithPercent:(float)percent maxQueries:(NSUInteger)maxQueries {
  self = [super init];
  if (self != nil) {
    self->_maxTrackedQueries = maxQueries;
    self->_percentOfQueries = percent;
    self->_pruneNext = NO;
  }
  return self;
}

- (void)pruneOnNextCheck {
  self.pruneNext = YES;
}

- (BOOL)shouldPruneCacheWithSize:(NSUInteger)cacheSize
          numberOfTrackedQueries:(NSUInteger)numTrackedQueries {
  if (self.pruneNext) {
    self.pruneNext = NO;
    return YES;
  } else {
    return NO;
  }
}

- (BOOL)shouldCheckCacheSize:(NSUInteger)serverUpdatesSinceLastCheck {
  return YES;
}

- (float)percentOfQueriesToPruneAtOnce {
  return self.percentOfQueries;
}

- (NSUInteger)maxNumberOfQueriesToKeep {
  return self.maxTrackedQueries;
}

@end
