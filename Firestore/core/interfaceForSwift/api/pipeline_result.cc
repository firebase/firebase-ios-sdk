
#include "Firestore/core/interfaceForSwift/api/pipeline_result.h"
#include "Firestore/core/include/firebase/firestore/timestamp.h"

namespace firebase {
namespace firestore {

namespace api {

PipelineResult::PipelineResult(std::shared_ptr<Firestore> firestore,
                               std::shared_ptr<Timestamp> execution_time,
                               std::shared_ptr<Timestamp> update_time,
                               std::shared_ptr<Timestamp> create_time)
    : firestore_(firestore),
      execution_time_(execution_time),
      update_time_(update_time),
      create_time_(create_time) {
}

PipelineResult PipelineResult::GetTestResult(
    std::shared_ptr<Firestore> firestore) {
  return PipelineResult(firestore, std::make_shared<Timestamp>(0, 0),
                        std::make_shared<Timestamp>(0, 0),
                        std::make_shared<Timestamp>(0, 0));
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase