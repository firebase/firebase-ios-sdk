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

#import "Firestore/Source/Util/FSTAsyncQueryListener.h"

using firebase::firestore::util::Executor;

@implementation FSTAsyncQueryListener {
  volatile BOOL _muted;
  FSTViewSnapshotHandler _snapshotHandler;
  Executor *_executor;
}

- (instancetype)initWithExecutor:(Executor *)executor
                 snapshotHandler:(FSTViewSnapshotHandler)snapshotHandler {
  if (self = [super init]) {
    _executor = executor;
    _snapshotHandler = snapshotHandler;
  }
  return self;
}

- (FSTViewSnapshotHandler)asyncSnapshotHandler {
  // Retain `self` strongly in resulting snapshot handler so that even if the
  // user releases the `FSTAsyncQueryListener` we'll continue to deliver
  // events. This is done specifically to facilitate the common case where
  // users just want to turn on notifications "forever" and don't want to have
  // to keep track of our handle to keep them going.
  return ^(FSTViewSnapshot *_Nullable snapshot, NSError *_Nullable error) {
    self->_executor->Execute([self, snapshot, error] {
      if (!self->_muted) {
        self->_snapshotHandler(snapshot, error);
      }
    });
  };
}

- (void)mute {
  _muted = true;
}

@end
