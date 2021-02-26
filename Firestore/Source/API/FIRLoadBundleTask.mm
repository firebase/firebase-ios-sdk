/*
 * Copyright 2021 Google LLC
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

#import "FIRLoadBundleTask.h"

#include <memory>

#include "Firestore/core/src/api/load_bundle_task.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/string_apple.h"

NS_ASSUME_NONNULL_BEGIN

namespace {

namespace api = firebase::firestore::api;
namespace util = firebase::firestore::util;

/**
 * Converts a public FIRLoadBundleTaskState into its internal equivalent.
 */
api::LoadBundleTaskState ConvertEnum(FIRLoadBundleTaskState state) {
  switch (state) {
    case FIRLoadBundleTaskStateInProgress:
      return api::LoadBundleTaskState::kInProgress;
    case FIRLoadBundleTaskStateSuccess:
      return api::LoadBundleTaskState::kSuccess;
    case FIRLoadBundleTaskStateError:
      return api::LoadBundleTaskState::kError;
    default:
      HARD_FAIL("Unexpected load bundle task state : %s", state);
  }
}

}  // namespace

@implementation FIRLoadBundleTaskProgress {
}

- (instancetype)initWithInternal:(api::LoadBundleTaskProgress)progress {
  if (self = [super init]) {
    _bytesLoaded = progress.bytes_loaded();
    _documentsLoaded = progress.documents_loaded();
    _totalBytes = progress.total_bytes();
    _totalDocuments = progress.total_documents();

    switch (progress.state()) {
      case api::LoadBundleTaskState::kInProgress:
        _state = FIRLoadBundleTaskStateInProgress;
        break;
      case api::LoadBundleTaskState::kSuccess:
        _state = FIRLoadBundleTaskStateSuccess;
        break;
      case api::LoadBundleTaskState::kError:
        _state = FIRLoadBundleTaskStateError;
        break;
    }
  }
  return self;
}

@end

@implementation FIRLoadBundleTask {
  std::shared_ptr<api::LoadBundleTask> _task;
}

- (instancetype)initWithTask:(std::shared_ptr<api::LoadBundleTask>)task {
  if (self = [super init]) {
    _task = std::move(task);
  }
  return self;
}

- (FIRLoadBundleHandle)observeState:(FIRLoadBundleTaskState)state
                            handler:(void (^)(FIRLoadBundleTaskProgress *progress))handler {
  if (!handler) {
    return nil;
  }

  api::LoadBundleTask::ProgressObserver observer =
      [handler](api::LoadBundleTaskProgress internal_progress) {
        handler([[FIRLoadBundleTaskProgress alloc] initWithInternal:internal_progress]);
      };
  return util::MakeNSString(_task->ObserveState(ConvertEnum(state), std::move(observer)));
}

- (void)removeObserverWithHandle:(FIRLoadBundleHandle)handle {
  _task->RemoveObserver(util::MakeString(handle));
}

- (void)removeAllObserversForState:(FIRLoadBundleTaskState)state {
  _task->RemoveObservers(ConvertEnum(state));
}

- (void)removeAllObservers {
  _task->RemoveAllObservers();
}

@end

NS_ASSUME_NONNULL_END
