//
// Created by Cheryl Lin on 2024-12-16.
//

#ifndef FIREBASE_PIPELINE_RESULT_H
#define FIREBASE_PIPELINE_RESULT_H

#include <memory>
#include "Firestore/core/include/firebase/firestore/timestamp.h"

namespace firebase {
namespace firestore {

namespace api {

class Firestore;
class DocumentReference;

class PipelineResult {
 public:
  PipelineResult(std::shared_ptr<Firestore> firestore,
                 std::shared_ptr<DocumentReference> doc_ref_ptr,
                 Timestamp execution_time,
                 Timestamp update_time,
                 Timestamp create_time);

 private:
  std::shared_ptr<Firestore> firestore_;
  std::shared_ptr<DocumentReference> doc_ref_ptr_;
  Timestamp execution_time_;
  Timestamp update_time_;
  Timestamp create_time_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase
#endif  // FIREBASE_PIPELINE_RESULT_H
