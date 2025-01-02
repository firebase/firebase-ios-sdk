#include "Firestore/core/swift/include/pipeline.h"

#include <future>  // NOLINT(build/c++11)
#include <memory>

#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/api/listener_registration.h"
#include "Firestore/core/src/api/source.h"
#include "Firestore/core/src/core/event_listener.h"
#include "Firestore/core/src/core/listen_options.h"
#include "Firestore/core/src/core/view_snapshot.h"
#include "Firestore/core/swift/include/pipeline_result.h"

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

  class ListenOnce : public EventListener<std::vector<PipelineResult>> {
   public:
    ListenOnce(PipelineSnapshotListener listener)
        : listener_(std::move(listener)) {
    }

    void OnEvent(
        StatusOr<std::vector<PipelineResult>> maybe_snapshot) override {
      if (!maybe_snapshot.ok()) {
        listener_->OnEvent(std::move(maybe_snapshot));
        return;
      }

      std::vector<PipelineResult> snapshot =
          std::move(maybe_snapshot).ValueOrDie();

      // Remove query first before passing event to user to avoid user actions
      // affecting the now stale query.
      std::unique_ptr<ListenerRegistration> registration =
          registration_promise_.get_future().get();
      registration->Remove();

      listener_->OnEvent(std::move(snapshot));
    };

    void Resolve(std::unique_ptr<ListenerRegistration> registration) {
      registration_promise_.set_value(std::move(registration));
    }

   private:
    PipelineSnapshotListener listener_;

    std::promise<std::unique_ptr<ListenerRegistration>> registration_promise_;
  };

  auto listener = absl::make_unique<ListenOnce>(std::move(callback));
  auto* listener_unowned = listener.get();

  //  std::unique_ptr<ListenerRegistration> registration =
  //      AddSnapshotListener(std::move(options), std::move(listener));
  //
  //  listener_unowned->Resolve(std::move(registration));
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase
