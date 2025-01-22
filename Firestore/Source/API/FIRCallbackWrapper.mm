/*
 * Copyright 2024 Google LLC
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

#import "FIRCallbackWrapper.h"

#include <memory>
#include <utility>
#include <vector>

#include "Firestore/core/interfaceForSwift/api/pipeline.h"
#include "Firestore/core/interfaceForSwift/api/pipeline_result.h"
#include "Firestore/core/src/core/event_listener.h"
#include "Firestore/core/src/util/error_apple.h"
#include "Firestore/core/src/util/statusor.h"

using firebase::firestore::api::PipelineResult;
using firebase::firestore::api::PipelineSnapshotListener;
using firebase::firestore::core::EventListener;
using firebase::firestore::util::MakeNSError;
using firebase::firestore::util::StatusOr;

@implementation FIRCallbackWrapper

// In public Swift documentation for integrating Swift and C++, using raw pointers in C++ is
// generally considered unsafe. However, during an experiment where the result was passed as a value
// instead of a pointer, a double free error occurred. This issue could not be traced effectively
// because the implementation resides within the Swift-C++ transition layer. In this specific use
// case, the C++ OnEvent() scope is destroyed after the Swift callback has been destroyed. Due to
// this ordering, using a raw pointer is a safe workaround for now.
+ (PipelineSnapshotListener)wrapPipelineCallback:(std::shared_ptr<api::Firestore>)firestore
                                      completion:(void (^)(CppPipelineResult *_Nullable result,
                                                           NSError *_Nullable error))completion {
  class Converter : public EventListener<CppPipelineResult> {
   public:
    explicit Converter(std::shared_ptr<api::Firestore> firestore, PipelineBlock completion)
        : firestore_(firestore), completion_(completion) {
    }

    void OnEvent(StatusOr<CppPipelineResult> maybe_snapshot) override {
      if (maybe_snapshot.ok()) {
        completion_(&maybe_snapshot.ValueOrDie(), nullptr);
      } else {
        completion_(nullptr, MakeNSError(maybe_snapshot.status()));
      }
    }

   private:
    std::shared_ptr<api::Firestore> firestore_;
    PipelineBlock completion_;
  };

  return std::make_shared<Converter>(firestore, completion);
}

@end
