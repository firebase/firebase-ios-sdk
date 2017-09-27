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

#import "FSTAsyncQueryListener.h"

#import "FSTDispatchQueue.h"

@implementation FSTAsyncQueryListener {
  volatile BOOL _muted;
  FSTViewSnapshotHandler _snapshotHandler;
  FSTDispatchQueue *_dispatchQueue;
}

- (instancetype)initWithDispatchQueue:(FSTDispatchQueue *)dispatchQueue
                      snapshotHandler:(FSTViewSnapshotHandler)snapshotHandler {
  if (self = [super init]) {
    _dispatchQueue = dispatchQueue;
    _snapshotHandler = snapshotHandler;
  }
  return self;
}

- (FSTViewSnapshotHandler)asyncSnapshotHandler {
  return ^(FSTViewSnapshot *_Nullable snapshot, NSError *_Nullable error) {
    [_dispatchQueue dispatchAsync:^{
      if (!_muted) {
        _snapshotHandler(snapshot, error);
      }
    }];
  };
}

- (void)mute {
  _muted = true;
}

@end
