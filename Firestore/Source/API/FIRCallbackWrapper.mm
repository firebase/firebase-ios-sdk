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

+ (PipelineSnapshotListener)wrapPipelineCallback:(std::shared_ptr<api::Firestore>)firestore
                                      completion:(void (^)(PipelineResultVector result,
                                                           NSError *_Nullable error))completion {
  class Converter : public EventListener<std::vector<PipelineResult>> {
   public:
    explicit Converter(std::shared_ptr<api::Firestore> firestore, PipelineBlock completion)
        : firestore_(firestore), completion_(completion) {
    }

    void OnEvent(StatusOr<std::vector<PipelineResult>> maybe_snapshot) override {
      if (maybe_snapshot.ok()) {
        completion_(
            std::initializer_list<PipelineResult>{PipelineResult::GetTestResult(firestore_)},
            nullptr);
      } else {
        completion_(std::initializer_list<PipelineResult>{}, MakeNSError(maybe_snapshot.status()));
      }
    }

   private:
    std::shared_ptr<api::Firestore> firestore_;
    PipelineBlock completion_;
  };

  return absl::make_unique<Converter>(firestore, completion);
}

@end
