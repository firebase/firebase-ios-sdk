#include <cstddef>
#include <cstdint>
#include <memory>
#include <sstream>
#include <string>
#include <utility>

#include "Firestore/core/src/bundle/bundle_reader.h"
#include "Firestore/core/src/bundle/bundle_serializer.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/remote/serializer.h"
#include "Firestore/core/src/util/byte_stream_cpp.h"

using firebase::firestore::bundle::BundleReader;
using firebase::firestore::bundle::BundleSerializer;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::remote::Serializer;
using firebase::firestore::util::ByteStreamCpp;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size == 0 || size > 64 * 1024) {
    return 0;
  }

  auto input = std::make_unique<std::stringstream>(
      std::string{reinterpret_cast<const char*>(data), size});
  auto stream = std::make_unique<ByteStreamCpp>(std::move(input));
  BundleReader reader{
      BundleSerializer{Serializer{DatabaseId{"project", "database"}}},
      std::move(stream)};

  while (reader.GetNextElement()) {
  }

  return 0;
}
