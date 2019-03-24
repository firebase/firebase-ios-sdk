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

#include <memory>

#import "Firestore/Source/API/FIRListenerRegistration+Internal.h"

#import "Firestore/Source/Core/FSTFirestoreClient.h"
#import "Firestore/Source/Util/FSTAsyncQueryListener.h"

NS_ASSUME_NONNULL_BEGIN

@implementation FSTListenerRegistration {
  /** The client that was used to register this listen. */
  FSTFirestoreClient *_client;

  /** The async listener that is used to mute events synchronously. */
  FSTAsyncQueryListener *_asyncListener;

  /** The internal QueryListener that can be used to unlisten the query. */
  std::weak_ptr<QueryListener> _internalListener;
}

- (instancetype)initWithClient:(FSTFirestoreClient *)client
                 asyncListener:(FSTAsyncQueryListener *)asyncListener
              internalListener:(std::shared_ptr<QueryListener>)internalListener {
  if (self = [super init]) {
    _client = client;
    _asyncListener = asyncListener;
    _internalListener = internalListener;
  }
  return self;
}

- (void)remove {
  [_asyncListener mute];

  std::shared_ptr<QueryListener> listener = _internalListener.lock();
  if (listener) {
    [_client removeListener:listener];
    listener.reset();
    _internalListener.reset();
  }
  _asyncListener = nil;
}

@end

NS_ASSUME_NONNULL_END
