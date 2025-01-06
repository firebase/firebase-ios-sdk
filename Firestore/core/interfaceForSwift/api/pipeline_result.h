//
// Created by Cheryl Lin on 2024-12-16.
//

#ifndef FIREBASE_PIPELINE_RESULT_H
#define FIREBASE_PIPELINE_RESULT_H

#include <memory>

namespace firebase {

class Timestamp;

namespace firestore {

namespace api {

class Firestore;
class DocumentReference;

class PipelineResult {
 public:
  PipelineResult(std::shared_ptr<Firestore> firestore,
                 std::shared_ptr<Timestamp> execution_time,
                 std::shared_ptr<Timestamp> update_time,
                 std::shared_ptr<Timestamp> create_time);

  static PipelineResult GetTestResult(std::shared_ptr<Firestore> firestore);

 private:
  std::shared_ptr<Firestore> firestore_;
  std::shared_ptr<Timestamp> execution_time_;
  std::shared_ptr<Timestamp> update_time_;
  std::shared_ptr<Timestamp> create_time_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase
#endif  // FIREBASE_PIPELINE_RESULT_H
