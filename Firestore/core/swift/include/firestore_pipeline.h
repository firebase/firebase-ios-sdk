//
// Created by Cheryl Lin on 2024-12-10.
//

#ifndef FIREBASE_FIRESTORE_PIPELINE_H
#define FIREBASE_FIRESTORE_PIPELINE_H

#include "pipeline_source.h"

namespace firebase {
namespace firestore {

namespace api {
class Firestore;

class FirestorePipeline {
 public:
  static PipelineSource pipeline(std::shared_ptr<Firestore> firestore);
};

}  // namespace api
}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_FIRESTORE_PIPELINE_H
