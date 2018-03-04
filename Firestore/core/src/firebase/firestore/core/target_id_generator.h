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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_TARGET_ID_GENERATOR_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_TARGET_ID_GENERATOR_H_

#include "Firestore/core/src/firebase/firestore/model/types.h"

namespace firebase {
namespace firestore {
namespace core {

/** The set of all valid generators. */
enum class TargetIdGeneratorId { LocalStore = 0, SyncEngine = 1 };

/**
 * Generates monotonically increasing integer IDs. There are separate generators
 * for different scopes. While these generators will operate independently of
 * each other, they are scoped, such that no two generators will ever produce
 * the same ID. This is useful, because sometimes the backend may group IDs from
 * separate parts of the client into the same ID space.
 *
 * Not thread-safe.
 */
class TargetIdGenerator {
 public:
  // Makes Objective-C++ code happy to provide a default ctor.
  TargetIdGenerator() = default;

  TargetIdGenerator(const TargetIdGenerator& value);

  /**
   * Creates and returns the TargetIdGenerator for the local store.
   *
   * @param after An ID to start at. Every call to NextId returns a larger id.
   * @return An instance of TargetIdGenerator.
   */
  static TargetIdGenerator LocalStoreTargetIdGenerator(model::TargetId after) {
    return TargetIdGenerator(TargetIdGeneratorId::LocalStore, after);
  }

  /**
   * Creates and returns the TargetIdGenerator for the sync engine.
   *
   * @param after An ID to start at. Every call to NextId returns a larger id.
   * @return An instance of TargetIdGenerator.
   */
  static TargetIdGenerator SyncEngineTargetIdGenerator(model::TargetId after) {
    return TargetIdGenerator(TargetIdGeneratorId::SyncEngine, after);
  }

  TargetIdGeneratorId generator_id() {
    return generator_id_;
  }

  model::TargetId NextId();

 private:
  TargetIdGenerator(TargetIdGeneratorId generator_id, model::TargetId after);
  TargetIdGeneratorId generator_id_;
  model::TargetId previous_id_;

  static const int kReservedBits = 1;
};

}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_CORE_TARGET_ID_GENERATOR_H_
