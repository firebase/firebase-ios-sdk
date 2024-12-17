
#include "Firestore/core/swift/include/pipeline_result.h"

namespace firebase {
namespace firestore {

namespace api {

PipelineResult::PipelineResult(std::shared_ptr<Firestore> firestore,
                               std::shared_ptr<DocumentReference> doc_ref_ptr,
                               Timestamp execution_time,
                               Timestamp update_time,
                               Timestamp create_time)
    : firestore_(firestore),
      doc_ref_ptr_(doc_ref_ptr),
      execution_time_(execution_time),
      update_time_(update_time),
      create_time_(create_time) {
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase