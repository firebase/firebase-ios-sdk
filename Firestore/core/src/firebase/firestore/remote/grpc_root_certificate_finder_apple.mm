/*
 * Copyright 2018 Google
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include "Firestore/core/src/firebase/firestore/remote/grpc_root_certificate_finder.h"

#include <string>

#include "Firestore/core/src/firebase/firestore/util/filesystem.h"
#include "Firestore/core/src/firebase/firestore/util/hard_assert.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"

#import "Firestore/Source/Core/FSTFirestoreClient.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::Path;
using util::ReadFile;
using util::StatusOr;
using util::StringFormat;

std::string LoadGrpcRootCertificate() {
  // TODO(varconst): uncomment these lines once it's possible to load the
  // certificate from gRPC-C++ pod.
  // NSBundle* bundle = [NSBundle bundleWithIdentifier:@"org.cocoapods.grpcpp"];
  // HARD_ASSERT(bundle, "Could not find grpcpp bundle");

  // `mainBundle` may be nil in certain cases (e.g., unit tests).
  NSBundle* bundle = [NSBundle bundleForClass:FSTFirestoreClient.class];
  HARD_ASSERT(bundle, "Could not find Firestore bundle");
  NSString* path =
      [bundle pathForResource:@"gRPCCertificates.bundle/roots" ofType:@"pem"];
  HARD_ASSERT(
      path,
      "Could not load root certificates from the bundle. SSL won't work.");

  StatusOr<std::string> certificate = ReadFile(Path::FromNSString(path));
  HARD_ASSERT(
      certificate.ok(),
      StringFormat("Unable to open root certificates at file path %s", path)
          .c_str());
  return certificate.ValueOrDie();
}

}  // namespace remote
}  // namespace firestore
}  // namespace firebase
