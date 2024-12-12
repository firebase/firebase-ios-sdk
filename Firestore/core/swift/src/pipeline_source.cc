
#include "Firestore/core/swift/include/pipeline_source.h"
#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/api/firestore.h"
#include "Firestore/core/swift/include/collection_stage.h"

namespace firebase {
namespace firestore {

namespace api {

PipelineSource::PipelineSource(std::shared_ptr<Firestore> firestore)
    : firestore_(firestore) {
}

Pipeline PipelineSource::GetCollection(std::string collection_path) {
  return {firestore_, Collection{collection_path}};
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase