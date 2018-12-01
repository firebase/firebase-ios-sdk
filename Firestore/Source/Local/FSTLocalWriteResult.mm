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

#import "Firestore/Source/Local/FSTLocalWriteResult.h"

#include <utility>

using firebase::firestore::model::BatchId;
using firebase::firestore::model::MaybeDocumentMap;

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalWriteResult ()
- (instancetype)initWithBatchID:(BatchId)batchID
                        changes:(MaybeDocumentMap &&)changes NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTLocalWriteResult {
  MaybeDocumentMap _changes;
}

- (const MaybeDocumentMap &)changes {
  return _changes;
}

+ (instancetype)resultForBatchID:(BatchId)batchID changes:(MaybeDocumentMap &&)changes {
  return [[FSTLocalWriteResult alloc] initWithBatchID:batchID changes:std::move(changes)];
}

- (instancetype)initWithBatchID:(BatchId)batchID changes:(MaybeDocumentMap &&)changes {
  self = [super init];
  if (self) {
    _batchID = batchID;
    _changes = std::move(changes);
  }
  return self;
}

@end

NS_ASSUME_NONNULL_END
