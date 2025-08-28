

#include <string>
#include <unordered_map>
#include <vector>
#include "Firestore/core/include/firebase/firestore/timestamp.h"
#include "Firestore/core/src/api/api_fwd.h"

namespace firebase {
namespace firestore {

namespace model {
class FieldPath;
class FieldValue;
}  // namespace model

namespace core {

class PipelineResult {
 public:
  PipelineResult();

  Timestamp getCreateTime() const;

  std::unordered_map<std::string, model::FieldValue> getData() const;

  api::DocumentReference getReference() const;
};
}  // namespace core

}  // namespace firestore
}  // namespace firebase