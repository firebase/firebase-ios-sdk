#include <cstddef>
#include <cstdint>

#include "Firestore/Protos/nanopb/google/firestore/admin/index.nanopb.h"
#include "Firestore/core/src/local/local_serializer.h"
#include "Firestore/core/src/model/database_id.h"
#include "Firestore/core/src/nanopb/message.h"
#include "Firestore/core/src/nanopb/reader.h"
#include "Firestore/core/src/remote/serializer.h"

using firebase::firestore::google_firestore_admin_v1_Index;
using firebase::firestore::local::LocalSerializer;
using firebase::firestore::model::DatabaseId;
using firebase::firestore::nanopb::Message;
using firebase::firestore::nanopb::StringReader;
using firebase::firestore::remote::Serializer;

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
  if (size > 16384) {
    return 0;
  }

  StringReader reader{data, size};
  auto message = Message<google_firestore_admin_v1_Index>::TryParse(&reader);
  if (!reader.ok()) {
    return 0;
  }

  LocalSerializer serializer{
      Serializer{DatabaseId{"project", DatabaseId::kDefault}}};
  (void)serializer.DecodeFieldIndexSegments(&reader, *message);
  return 0;
}