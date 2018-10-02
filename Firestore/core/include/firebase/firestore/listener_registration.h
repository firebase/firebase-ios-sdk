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

#ifndef FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_LISTENER_REGISTRATION_H_
#define FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_LISTENER_REGISTRATION_H_

namespace firebase {
namespace firestore {

class FirestoreInternal;
class ListenerRegistrationInternal;

/** Represents a listener that can be removed by calling remove. */
class ListenerRegistration {
 public:
  /**
   * @brief Default constructor. This creates a no-op instance.
   */
  ListenerRegistration();

  /**
   * @brief Copy constructor. It's totally okay to copy ListenerRegistration
   * instances.
   *
   * @param[in] registration ListenerRegistration to copy from.
   */
  ListenerRegistration(const ListenerRegistration& registration);

  /**
   * @brief Move constructor. Moving is an efficient operation for
   * ListenerRegistration instances.
   *
   * @param[in] registration ListenerRegistration to move data from.
   */
  ListenerRegistration(ListenerRegistration&& registration);

  ~ListenerRegistration();

  /**
   * @brief Copy assignment operator. It's totally okay to copy
   * ListenerRegistration instances.
   *
   * @param[in] registration ListenerRegistration to copy from.
   *
   * @returns Reference to the destination ListenerRegistration.
   */
  ListenerRegistration& operator=(const ListenerRegistration& registration);

  /**
   * @brief Move assignment operator. Moving is an efficient operation for
   * ListenerRegistration instances.
   *
   * @param[in] registration ListenerRegistration to move data from.
   *
   * @returns Reference to the destination ListenerRegistration.
   */
  ListenerRegistration& operator=(ListenerRegistration&& registration);

  /**
   * Removes the listener being tracked by this ListenerRegistration. After the
   * initial call, subsequent calls have no effect.
   */
  void Remove();

 private:
  friend class DocumentReferenceInternal;
  friend class FirestoreInternal;
  friend class ListenerRegistrationInternal;
  friend class QueryInternal;

  explicit ListenerRegistration(ListenerRegistrationInternal* internal);

  FirestoreInternal* firestore_ = nullptr;
  ListenerRegistrationInternal* internal_ = nullptr;
};

}  // namespace firestore
}  // namespace firebase

#endif  // FIRESTORE_CORE_INCLUDE_FIREBASE_FIRESTORE_LISTENER_REGISTRATION_H_
