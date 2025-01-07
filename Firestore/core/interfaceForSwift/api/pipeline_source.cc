#include "Firestore/core/interfaceForSwift/api/pipeline_source.h"
#include "Firestore/core/interfaceForSwift/api/collection_stage.h"
#include "Firestore/core/src/api/document_reference.h"
#include "Firestore/core/src/api/firestore.h"

namespace firebase {
namespace firestore {

namespace api {

PipelineSource::PipelineSource(std::shared_ptr<Firestore> firestore)
    : firestore_(firestore) {
  std::cout << "PipelineSource constructs" << std::endl;
}

Pipeline PipelineSource::GetCollection(std::string collection_path) const {
  return {firestore_, Collection{collection_path}};
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase
