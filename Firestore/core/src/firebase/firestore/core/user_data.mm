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

#include "Firestore/core/src/firebase/firestore/core/user_data.h"

#include <utility>

#import "Firestore/Source/Model/FSTMutation.h"

namespace firebase {
namespace firestore {
namespace core {

using model::DocumentKey;
using model::FieldMask;
using model::FieldTransform;
using model::Precondition;

ParsedSetData::ParsedSetData(FSTObjectValue* data,
                             std::vector<FieldTransform> field_transforms)
    : data_{data},
      field_transforms_{std::move(field_transforms)},
      patch_{false} {
}

ParsedSetData::ParsedSetData(FSTObjectValue* data,
                             FieldMask field_mask,
                             std::vector<FieldTransform> field_transforms)
    : data_{data},
      field_mask_{std::move(field_mask)},
      field_transforms_{std::move(field_transforms)},
      patch_{true} {
}

NSArray<FSTMutation*>* ParsedSetData::ToMutations(
    const DocumentKey& key, const Precondition& precondition) && {
  NSMutableArray<FSTMutation*>* mutations = [NSMutableArray array];
  if (patch_) {
    [mutations
        addObject:[[FSTPatchMutation alloc] initWithKey:key
                                              fieldMask:std::move(field_mask_)
                                                  value:std::move(data_)
                                           precondition:precondition]];
  } else {
    [mutations addObject:[[FSTSetMutation alloc] initWithKey:key
                                                       value:std::move(data_)
                                                precondition:precondition]];
  }
  if (!field_transforms_.empty()) {
    [mutations
        addObject:[[FSTTransformMutation alloc] initWithKey:key
                                            fieldTransforms:field_transforms_]];
  }
  return mutations;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
