//
// Created by Cheryl Lin on 2024-12-11.
//

#ifndef FIREBASE_COLLECTION_GROUP_STAGE_H
#define FIREBASE_COLLECTION_GROUP_STAGE_H

#include <string>
#include "stage.h"

namespace firebase {
namespace firestore {

namespace api {

class Collection : public Stage {
 public:
  Collection(std::string collection_path);

 private:
  std::string collection_path_;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase

#endif  // FIREBASE_COLLECTION_GROUP_STAGE_H
