/*
 * Copyright 2025 Google LLC
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

#import "FirebaseRemoteConfig/Sources/RCNConfigSessionConfiguration.h"

@implementation RCNConfigSessionConfiguration

+ (NSURLSessionConfiguration *)remoteConfigSessionConfiguration {
  // Check if the current operating system version meets the criteria of the affected simulators.
  if (@available(iOS 18.4, tvOS 100.0, watchOS 100.0, visionOS 2.4, *)) {
    // If the app is running on one of the affected simulator versions (or later for iOS and
    // visionOS), use an ephemeral session configuration. Ephemeral sessions do not persist caches,
    // cookies, or credential data to disk, which circumvents the known bug.
    return [NSURLSessionConfiguration ephemeralSessionConfiguration];
  }
  return [NSURLSessionConfiguration defaultSessionConfiguration];
}

@end
