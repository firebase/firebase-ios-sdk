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

#import <FirebaseCore/FIRApp.h>
#import <FirebaseCore/FIROptions.h>

#include "Firestore/core/src/firebase/firestore/util/string_apple.h"
#include "Firestore/core/test/firebase/firestore/testutil/app_testing.h"

namespace firebase {
namespace firestore {
namespace testutil {

FIROptions* OptionsForUnitTesting(const absl::string_view project_id) {
  FIROptions* options =
      [[FIROptions alloc] initWithGoogleAppID:@"1:123:ios:123ab"
                                  GCMSenderID:@"gcm_sender_id"];
  options.projectID = util::MakeNSString(project_id);
  return options;
}

FIRApp* AppForUnitTesting(const absl::string_view project_id) {
  static int counter = 0;

  NSString* appName =
      [NSString stringWithFormat:@"app_for_unit_testing_%d", counter++];
  FIROptions* options = OptionsForUnitTesting(project_id);
  [FIRApp configureWithName:appName options:options];

  return [FIRApp appNamed:appName];
}

}  // namespace testutil
}  // namespace firestore
}  // namespace firebase
