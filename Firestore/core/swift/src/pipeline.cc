#include "Firestore/core/swift/include/pipeline.h"
#include <memory>
#include "Firestore/core/src/api/firestore.h"

namespace firebase {
namespace firestore {

namespace api {

Pipeline::Pipeline(std::shared_ptr<Firestore> firestore, Stage stage)
    : firestore_(firestore), stage_(stage) {
}

}  // namespace api

}  // namespace firestore
}  // namespace firebase