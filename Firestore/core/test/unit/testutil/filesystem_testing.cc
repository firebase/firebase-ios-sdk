/*
 * Copyright 2020 Google LLC
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

#include "Firestore/core/test/unit/testutil/filesystem_testing.h"

#include <fstream>

#include "Firestore/core/src/util/autoid.h"
#include "Firestore/core/src/util/filesystem.h"
#include "Firestore/core/src/util/hard_assert.h"
#include "Firestore/core/src/util/log.h"
#include "Firestore/core/src/util/path.h"
#include "gtest/gtest.h"

namespace firebase {
namespace firestore {
namespace testutil {

using util::CreateAutoId;
using util::Filesystem;
using util::Path;
using util::Status;

Path RandomFilename() {
  return Path::FromUtf8("firestore-testing-" + CreateAutoId());
}

void Touch(const Path& path) {
  std::ofstream out{path.native_value()};
  ASSERT_TRUE(out.good());
}

TestTempDir::TestTempDir(Filesystem* fs)
    : fs_(fs ? fs : Filesystem::Default()) {
  path_ = Path::JoinUtf8(fs_->TempDir(), RandomFilename());
  auto created = fs_->RecursivelyCreateDir(path_);
  if (!created.ok()) {
    ADD_FAILURE() << "Failed to create test directory " << path_.ToUtf8String()
                  << ": " << created.ToString();
    HARD_FAIL();
  }
}

TestTempDir::~TestTempDir() {
  Status removed = fs_->RecursivelyRemove(path_);
  if (!removed.ok()) {
    LOG_WARN("Failed to clean up temp dir %s: %s", path_.ToUtf8String(),
             removed.ToString());
  }
}

Path TestTempDir::Child(const char* child) const {
  return Path::JoinUtf8(path_, child);
}

Path TestTempDir::RandomChild() const {
  return Path::JoinUtf8(path_, "child-" + CreateAutoId());
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
