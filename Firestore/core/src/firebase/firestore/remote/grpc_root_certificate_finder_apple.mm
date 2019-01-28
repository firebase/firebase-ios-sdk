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
#include "Firestore/core/src/firebase/firestore/util/log.h"
#include "Firestore/core/src/firebase/firestore/util/statusor.h"

#import "Firestore/Source/Core/FSTFirestoreClient.h"

namespace firebase {
namespace firestore {
namespace remote {

using util::Path;
using util::ReadFile;
using util::StatusOr;
using util::StringFormat;

NSString* FindPathToCertificatesFile() {
  // Certificates file might be present in either the gRPC-C++ bundle or (for
  // some projects) in the main bundle.
  NSBundle* bundles[] = {
      // Try to load certificates bundled by gRPC-C++.
      [NSBundle bundleWithIdentifier:@"org.cocoapods.grpcpp"],
      // Users manually adding resources to the project may add the
      // certificate to the main application bundle. Note that `mainBundle` is
      // nil for unit tests of library projects, so it cannot fully substitute
      // for checking the framework bundle.
      [NSBundle mainBundle],
  };

  // search for the roots.pem file in each of these resource locations
  NSString* possibleResources[] = {
      @"gRPCCertificates.bundle/roots",
      @"roots",
  };

  for (NSBundle* bundle : bundles) {
    if (!bundle) {
      continue;
    }

    for (NSString* resource : possibleResources) {
      NSString* path = [bundle pathForResource:resource ofType:@"pem"];
      if (path) {
        LOG_DEBUG("%s.pem found in bundle %s", resource,
                  [bundle bundleIdentifier]);
        return path;
      } else {
        LOG_DEBUG("%s.pem not found in bundle %s", resource,
                  [bundle bundleIdentifier]);
      }
    }
  }
  return nil;
}

std::string LoadGrpcRootCertificate() {
  NSString* path = FindPathToCertificatesFile();
  HARD_ASSERT(
      path,
      "Could not load root certificates from the bundle. SSL cannot work.");

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
