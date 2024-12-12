//
// Created by Cheryl Lin on 2024-12-11.
//

#ifndef FIREBASE_PIPELINE_H
#define FIREBASE_PIPELINE_H

#include <memory>
#include "stage.h"

namespace firebase {
namespace firestore {

namespace api {

class Firestore;

class Pipeline {
 public:
  Pipeline(std::shared_ptr<Firestore> firestore, Stage stage);

 private:
  std::shared_ptr<Firestore> firestore_;
  Stage stage_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_PIPELINE_H
