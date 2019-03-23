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

#include "Firestore/core/src/firebase/firestore/api/listener_registration.h"

#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"

namespace firebase {
namespace firestore {
namespace api {

void ListenerRegistration::Remove() {
  [async_listener_ mute];
  async_listener_ = nil;

  std::shared_ptr<QueryListener> listener = internal_listener_.lock();
  if (listener) {
    [client_ removeListener:listener];
    listener.reset();
    internal_listener_.reset();
  }
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase
