/*
 * Copyright 2023 Google LLC
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

#import "FirebaseAppCheck/Sources/Core/FIRApp+AppCheck.h"

@implementation FIRApp (AppCheck)

- (NSString *)resourceName {
  return [NSString
      stringWithFormat:@"projects/%@/apps/%@", self.options.projectID, self.options.googleAppID];
}

@end

/// Stub used to force the linker to include the categories in this file.
void FIRInclude_FIRApp_AppCheck_Category(void) {
}
