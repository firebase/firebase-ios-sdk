#include "Firestore/core/swift/include/firestore_pipeline.h"
#include "Firestore/core/src/api/firestore.h"

namespace firebase {
namespace firestore {

namespace api {

PipelineSource FirestorePipeline::pipeline(
    std::shared_ptr<Firestore> firestore) {
  return firestore->pipeline();
}

}  // namespace api
}  // namespace firestore
}  // namespace firebase