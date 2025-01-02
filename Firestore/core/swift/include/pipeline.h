//
// Created by Cheryl Lin on 2024-12-11.
//

#ifndef FIREBASE_PIPELINE_H
#define FIREBASE_PIPELINE_H

#include <functional>
#include <memory>
#include <vector>
#include "pipeline_result.h"
#include "stage.h"

namespace firebase {
namespace firestore {

namespace core {
template <typename T>
class EventListener;
}  // namespace core

namespace api {

class Firestore;
class PipelineResult;

using PipelineSnapshotListener =
    std::unique_ptr<core::EventListener<std::vector<PipelineResult>>>;

class Pipeline {
 public:
  Pipeline(std::shared_ptr<Firestore> firestore, Stage stage);

  void GetPipelineResult(
      std::function<void(PipelineResult, bool)> callback) const;

  std::shared_ptr<Firestore> GetFirestore() const {
    return firestore_;
  }

 private:
  std::shared_ptr<Firestore> firestore_;
  Stage stage_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_PIPELINE_H
