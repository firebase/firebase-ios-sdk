/*
 * Copyright 2019 Google
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

#ifndef FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_LISTENER_REGISTRATION_H_
#define FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_LISTENER_REGISTRATION_H_

#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/core/event_listener.h"
#include "Firestore/core/src/firebase/firestore/core/query_listener.h"
#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/util/nullability.h"

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace core {
class FirestoreClient;
}

namespace api {

/**
 * An internal handle that encapsulates a user's ability to request that we
 * stop listening to a listener.
 */
class ListenerRegistration {
 public:
  virtual ~ListenerRegistration() = default;

  /**
   * Removes the listener being tracked in this ListenerRegistration.
   */
  virtual void Remove() = 0;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_LISTENER_REGISTRATION_H_
