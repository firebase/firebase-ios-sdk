//
// Created by Cheryl Lin on 2024-11-13.
//

#ifndef FIREBASE_PIPELINE_H
#define FIREBASE_PIPELINE_H

#include <vector>
#include "Firestore/core/src/called_by_swift/include/pipeline_result.h"

namespace firebase {
namespace firestore {
namespace core {
class Pipeline {
 public:
  Pipeline();

  std::vector<PipelineResult> execute();
};
}  // namespace core
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_PIPELINE_H
