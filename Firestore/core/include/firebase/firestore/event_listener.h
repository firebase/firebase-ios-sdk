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

// TODO(rsgowman): This file isn't intended to be used just yet. It's just an
// outline of what the API might eventually look like. Most of this was
// shamelessly stolen and modified from rtdb's header file, melded with the
// (java) firestore api.

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_EVENT_LISTENER_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_EVENT_LISTENER_H_

namespace firebase {
namespace firestore {

// TODO(rsgowman): replace these forward decl's with appropriate includes (once
// they exist)
class Error;

/**
 * @brief An interface for event listeners.
 */
template <typename T>
class EventListener {
 public:
  /**
   * @brief OnEvent will be called with the new value or the error if an error
   * occurred.
   *
   * It's guaranteed that exactly one of value or error will be non-null.
   *
   * @param value The value of the event. null if there was an error.
   * @param error The error if there was error. null otherwise.
   */
  void OnEvent(const T* value, const Error* error);
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_EVENT_LISTENER_H_
