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

#include "Firestore/core/src/firebase/firestore/core/event_listener.h"
#include "Firestore/core/src/firebase/firestore/core/query_listener.h"

@class FSTFirestoreClient;

NS_ASSUME_NONNULL_BEGIN

namespace firebase {
namespace firestore {
namespace api {

/**
 * An internal handle that encapsulates a user's ability to request that we
 * stop listening to a query. When a user calls Remove(), ListenerRegistration
 * will synchronously mute the listener and then send a request to the
 * FirestoreClient to actually unlisten.
 *
 * ListenerRegistration will not automaticlaly stop listening if it is
 * destroyed. We allow users to fire and forget listens if they never want to
 * stop them.
 *
 * Getting shutdown code right is tricky so ListenerRegistration is very
 * forgiving. It will tolerate:
 *
 *   * Multiple calls to Remove(),
 *   * calls to Remove() after we send an error,
 *   * calls to Remove() even after deleting the App in which the listener was
 *     started.
 */
class ListenerRegistration {
 public:
  ListenerRegistration(
      FSTFirestoreClient* client,
      std::shared_ptr<core::AsyncEventListener<core::ViewSnapshot>>
          async_listener,
      std::shared_ptr<core::QueryListener> query_listener)
      : client_(client),
        async_listener_(std::move(async_listener)),
        query_listener_(std::move(query_listener)) {
  }

  /**
   * Removes the listener being tracked by this FIRListenerRegistration. After
   * the initial call, subsequent calls have no effect.
   */
  void Remove();

 private:
  /** The client that was used to register this listen. */
  FSTFirestoreClient* client_ = nil;

  /** The async listener that is used to mute events synchronously. */
  std::weak_ptr<core::AsyncEventListener<core::ViewSnapshot>> async_listener_;

  /** The internal QueryListener that can be used to unlisten the query. */
  std::weak_ptr<core::QueryListener> query_listener_;
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

NS_ASSUME_NONNULL_END

#endif  // FIRESTORE_CORE_SRC_FIREBASE_FIRESTORE_API_LISTENER_REGISTRATION_H_
