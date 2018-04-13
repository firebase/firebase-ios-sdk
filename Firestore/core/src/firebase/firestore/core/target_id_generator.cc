/*
 * Copyright 2018 Google
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

#include "Firestore/core/src/firebase/firestore/core/target_id_generator.h"

using firebase::firestore::model::TargetId;

namespace firebase {
namespace firestore {
namespace core {

TargetIdGenerator::TargetIdGenerator(const TargetIdGenerator& value)
    : generator_id_(value.generator_id_), previous_id_(value.previous_id_) {
}

TargetIdGenerator::TargetIdGenerator(TargetIdGeneratorId generator_id,
                                     TargetId after)
    : generator_id_(generator_id) {
  const TargetId after_without_generator = (after >> kReservedBits)
                                           << kReservedBits;
  const TargetId after_generator = after - after_without_generator;
  const TargetId generator = static_cast<TargetId>(generator_id);
  if (after_generator >= generator) {
    // For example, if:
    //   self.generatorID = 0b0000
    //   after = 0b1011
    //   afterGenerator = 0b0001
    // Then:
    //   previous = 0b1010
    //   next = 0b1100
    previous_id_ = after_without_generator | generator;
  } else {
    // For example, if:
    //   self.generatorID = 0b0001
    //   after = 0b1010
    //   afterGenerator = 0b0000
    // Then:
    //   previous = 0b1001
    //   next = 0b1011
    previous_id_ = (after_without_generator | generator) - (1 << kReservedBits);
  }
}

TargetId TargetIdGenerator::NextId() {
  previous_id_ += 1 << kReservedBits;
  return previous_id_;
}

}  // namespace core
}  // namespace firestore
}  // namespace firebase
