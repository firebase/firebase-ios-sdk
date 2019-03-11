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

#import <Foundation/Foundation.h>

#include "Firestore/core/src/firebase/firestore/core/view_snapshot.h"
#include "Firestore/core/src/firebase/firestore/util/executor.h"

NS_ASSUME_NONNULL_BEGIN

@class FSTQueryListener;

/**
 * A wrapper class around FSTQueryListener that dispatches events asynchronously.
 */
@interface FSTAsyncQueryListener : NSObject

- (instancetype)initWithExecutor:(firebase::firestore::util::Executor*)executor
                 snapshotHandler:(firebase::firestore::core::ViewSnapshotHandler&&)snapshotHandler
    NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Synchronously mutes the listener and raise no further events. This method is thread safe can be
 * called from any queue.
 */
- (void)mute;

/** Creates an asynchronous version of the provided snapshot handler. */
- (firebase::firestore::core::ViewSnapshotHandler)asyncSnapshotHandler;

@end

NS_ASSUME_NONNULL_END
