// Copyright 2025 Google LLC
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

#include "Firestore/core/interfaceForSwift/api/Pipeline.h"

#include <future>
#include <memory>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/interfaceForSwift/api/PipelineResult.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/listener_registration.h"
#include "Firestore/core/src/api/source.h"
#include "Firestore/core/src/core/event_listener.h"
#include "Firestore/core/src/core/listen_options.h"
#include "Firestore/core/src/core/view_snapshot.h"

namespace firebase {
namespace firestore {

namespace api {

using core::EventListener;
using core::ListenOptions;
using core::ViewSnapshot;

Pipeline::Pipeline(std::shared_ptr<Firestore> firestore, Stage stage)
    : firestore_(firestore), stage_(stage) {
}

void Pipeline::GetPipelineResult(PipelineSnapshotListener callback) const {
  ListenOptions options(
      /*include_query_metadata_changes=*/true,
      /*include_document_metadata_changes=*/true,
      /*wait_for_sync_when_online=*/true);

  PipelineResult sample = PipelineResult::GetTestResult(firestore_);

  StatusOr<PipelineResult> res(sample);
  callback->OnEvent(res);

  //  class ListenOnce : public EventListener<std::vector<PipelineResult>> {
  //   public:
  //    ListenOnce(PipelineSnapshotListener listener)
  //        : listener_(std::move(listener)) {
  //    }
  //
  //    void OnEvent(
  //        StatusOr<std::vector<PipelineResult>> maybe_snapshot) override {
  //      if (!maybe_snapshot.ok()) {
  //        listener_->OnEvent(std::move(maybe_snapshot));
  //        return;
  //      }
  //
  //      std::vector<PipelineResult> snapshot =
  //          std::move(maybe_snapshot).ValueOrDie();
  //
  //      // Remove query first before passing event to user to avoid user
  //      actions
  //      // affecting the now stale query.
  //      std::unique_ptr<ListenerRegistration> registration =
  //          registration_promise_.get_future().get();
  //      registration->Remove();
  //
  //      listener_->OnEvent(std::move(snapshot));
  //    };
  //
  //    void Resolve(std::unique_ptr<ListenerRegistration> registration) {
  //      registration_promise_.set_value(std::move(registration));
  //    }
  //
  //   private:
  //    PipelineSnapshotListener listener_;
  //
  //    std::promise<std::unique_ptr<ListenerRegistration>>
  //    registration_promise_;
  //  };
  //
  //  auto listener = absl::make_unique<ListenOnce>(std::move(callback));
  //  auto* listener_unowned = listener.get();

  //  std::unique_ptr<ListenerRegistration> registration =
  //      AddSnapshotListener(std::move(options), std::move(listener));
  //
  //  listener_unowned->Resolve(std::move(registration));
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase
