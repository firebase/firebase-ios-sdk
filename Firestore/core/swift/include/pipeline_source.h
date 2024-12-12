//
// Created by Cheryl Lin on 2024-12-09.
//

#ifndef FIREBASE_PIPELINE_SOURCE_H
#define FIREBASE_PIPELINE_SOURCE_H

#include <memory>
#include <vector>
#include "pipeline.h"

namespace firebase {
namespace firestore {

namespace api {

class Firestore;
class DocumentReference;

class PipelineSource {
 public:
  PipelineSource(std::shared_ptr<Firestore> firestore);

  Pipeline GetCollection(std::string collection_path);

 private:
  std::shared_ptr<Firestore> firestore_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_PIPELINE_SOURCE_H
