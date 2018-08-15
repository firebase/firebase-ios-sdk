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

#import "Firestore/Source/Model/FSTDocumentDictionary.h"

#include "Firestore/core/src/firebase/firestore/model/types.h"

NS_ASSUME_NONNULL_BEGIN

/** The result of a write to the local store. */
@interface FSTLocalWriteResult : NSObject

+ (instancetype)resultForBatchID:(firebase::firestore::model::BatchId)batchID
                         changes:(FSTMaybeDocumentDictionary *)changes;

- (id)init __attribute__((unavailable("Use resultForBatchID:changes:")));

@property(nonatomic, assign, readonly) firebase::firestore::model::BatchId batchID;
@property(nonatomic, strong, readonly) FSTMaybeDocumentDictionary *changes;

@end

NS_ASSUME_NONNULL_END
