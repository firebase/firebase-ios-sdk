#include "Firestore/core/swift/include/pipeline.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/core/event_listener.h"

namespace firebase {
namespace firestore {

namespace api {

Pipeline::Pipeline(std::shared_ptr<Firestore> firestore, Stage stage)
    : firestore_(firestore), stage_(stage) {
}

std::shared_ptr<PipelineSnapshotListener> Pipeline::GetPipelineResult() {
  return {};
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase