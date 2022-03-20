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

#import "FirebaseCore/Internal/FIRAppInternal.h"
#import "FirebaseCore/Internal/FIROptionsInternal.h"

#include "Firestore/core/src/util/string_apple.h"
#include "Firestore/core/test/unit/testutil/app_testing.h"

namespace firebase {
namespace firestore {
namespace testutil {

FIROptions* OptionsForUnitTesting(absl::string_view project_id) {
  FIROptions* options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123ab"
                                  GCMSenderID:@"gcm_sender_id"];
  options.projectID = util::MakeNSString(project_id);
  return options;
}

FIRApp* AppForUnitTesting(absl::string_view project_id) {
  FIROptions* options = OptionsForUnitTesting(project_id);
  return AppForUnitTesting(options);
}

FIRApp* AppForUnitTesting(FIROptions* options) {
  static int counter = 0;

  NSString* app_name =
      [NSString stringWithFormat:@"app_for_unit_testing_%d", counter++];
  [FIRApp configureWithName:app_name options:options];
  return [FIRApp appNamed:app_name];
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
