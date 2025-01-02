#include "Firestore/core/swift/include/pipeline.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/src/core/event_listener.h"
#include "Firestore/core/swift/include/pipeline_result.h"

namespace firebase {
namespace firestore {

namespace api {

Pipeline::Pipeline(std::shared_ptr<Firestore> firestore, Stage stage)
    : firestore_(firestore), stage_(stage) {
}

void Pipeline::GetPipelineResult(
    std::function<void(PipelineResult, bool)> callback) const {
  callback(PipelineResult(firestore_, std::make_shared<Timestamp>(0, 0),
                          std::make_shared<Timestamp>(0, 0),
                          std::make_shared<Timestamp>(0, 0)),
           true);
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase
