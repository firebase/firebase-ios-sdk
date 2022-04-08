// Copyright 2017 Google
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FirebaseStorageInternal/Sources/Public/FirebaseStorageInternal/FIRStorageTaskSnapshot.h"

#import "FirebaseStorageInternal/Sources/FIRStorageTaskSnapshot_Private.h"

#import "FirebaseStorageInternal/Sources/FIRStorageTask_Private.h"

@implementation FIRIMPLStorageTaskSnapshot

- (instancetype)initWithTask:(__kindof FIRIMPLStorageTask *)task
                       state:(FIRIMPLStorageTaskState)state
                    metadata:(nullable FIRIMPLStorageMetadata *)metadata
                   reference:(FIRIMPLStorageReference *)reference
                    progress:(nullable NSProgress *)progress
                       error:(nullable NSError *)error {
  self = [super init];
  if (self) {
    _task = task;
    _metadata = metadata;
    _reference = reference;
    _progress = progress;
    _error = error;

    switch (state) {
      case FIRIMPLStorageTaskStateQueueing:
      case FIRIMPLStorageTaskStateRunning:
      case FIRIMPLStorageTaskStateResuming:
        _status = FIRIMPLStorageTaskStatusResume;
        break;

      case FIRIMPLStorageTaskStateProgress:
        _status = FIRIMPLStorageTaskStatusProgress;
        break;

      case FIRIMPLStorageTaskStatePaused:
      case FIRIMPLStorageTaskStatePausing:
        _status = FIRIMPLStorageTaskStatusPause;
        break;

      case FIRIMPLStorageTaskStateSuccess:
      case FIRIMPLStorageTaskStateCompleting:
        _status = FIRIMPLStorageTaskStatusSuccess;
        break;

      case FIRIMPLStorageTaskStateCancelled:
      case FIRIMPLStorageTaskStateFailing:
      case FIRIMPLStorageTaskStateFailed:
        _status = FIRIMPLStorageTaskStatusFailure;
        break;

      default:
        _status = FIRIMPLStorageTaskStatusUnknown;
    }
  }
  return self;
}

- (NSString *)description {
  switch (_status) {
    case FIRIMPLStorageTaskStatusResume:
      return @"<State: Resume>";
    case FIRIMPLStorageTaskStatusProgress:
      return [NSString stringWithFormat:@"<State: Progress, Progress: %@>", _progress];
    case FIRIMPLStorageTaskStatusPause:
      return @"<State: Paused>";
    case FIRIMPLStorageTaskStatusSuccess:
      return @"<State: Success>";
    case FIRIMPLStorageTaskStatusFailure:
      return [NSString stringWithFormat:@"<State: Failed, Error: %@>", _error];
    default:
      return @"<State: Unknown>";
  };
}

@end
