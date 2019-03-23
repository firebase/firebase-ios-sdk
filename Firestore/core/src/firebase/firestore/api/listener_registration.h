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

#if !defined(__OBJC__)
#error "This header only supports Objective-C++"
#endif  // !defined(__OBJC__)

#import <Foundation/Foundation.h>

#include <memory>
#include <utility>

#include "Firestore/core/src/firebase/firestore/core/query_listener.h"

@class FSTAsyncQueryListener;
@class FSTFirestoreClient;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace api {

class ListenerRegistration {
 public:
  ListenerRegistration() = default;

  ListenerRegistration(FSTFirestoreClient* client,
                       FSTAsyncQueryListener* async_listener,
                       std::shared_ptr<core::QueryListener> internal_listener)
      : client_(client),
        async_listener_(async_listener),
        internal_listener_(std::move(internal_listener)) {
  }

  // Move-only to prevent copies from proliferating.
  ListenerRegistration(const ListenerRegistration&) = delete;
  ListenerRegistration(ListenerRegistration&&) noexcept = default;

  ListenerRegistration& operator=(const ListenerRegistration&) = delete;
  ListenerRegistration& operator=(ListenerRegistration&& other) noexcept {
    client_ = std::move(other.client_);
    async_listener_ = std::move(other.async_listener_);
    internal_listener_ = std::move(other.internal_listener_);
    return *this;
  };

  /**
   * Removes the listener being tracked by this FIRListenerRegistration. After
   * the initial call, subsequent calls have no effect.
   */
  void Remove();

 private:
  /** The client that was used to register this listen. */
  FSTFirestoreClient* client_;

  /** The async listener that is used to mute events synchronously. */
  FSTAsyncQueryListener* async_listener_;

  /** The internal QueryListener that can be used to unlisten the query. */
  std::weak_ptr<core::QueryListener> internal_listener_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_LISTENER_REGISTRATION_H_
