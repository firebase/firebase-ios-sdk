#include "Firestore/core/swift/include/collection_stage.h"
#include <iostream>

namespace firebase {
namespace firestore {

namespace api {

Collection::Collection(std::string collection_path)
    : collection_path_(collection_path) {
  std::cout << "Calling Pipeline Collection ctor" << std::endl;
};

}  // namespace api

}  // namespace firestore
}  // namespace firebase