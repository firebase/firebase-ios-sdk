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

NS_ASSUME_NONNULL_BEGIN

@interface FSTLocalWriteResult ()
- (instancetype)initWithBatchID:(FSTBatchID)batchID
                        changes:(MaybeDocumentDictionary)changes NS_DESIGNATED_INITIALIZER;
@end

@implementation FSTLocalWriteResult {
  MaybeDocumentDictionary _changes;
}

+ (instancetype)resultForBatchID:(FSTBatchID)batchID changes:(MaybeDocumentDictionary)changes {
  return [[FSTLocalWriteResult alloc] initWithBatchID:batchID changes:std::move(changes)];
}

- (instancetype)initWithBatchID:(FSTBatchID)batchID changes:(MaybeDocumentDictionary)changes {
  self = [super init];
  if (self) {
    _batchID = batchID;
    _changes = std::move(changes);
  }
  return self;
}

- (const MaybeDocumentDictionary &)changes {
  return _changes;
}

@end

NS_ASSUME_NONNULL_END
