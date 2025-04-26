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

#import <Foundation/Foundation.h>

@interface RCNConfigSessionConfiguration : NSObject

/// Returns an `NSURLSessionConfiguration` instance suitable for Remote Config requests.
///
/// On iOS 18.4+ and visionOS 2.4+ simulators, this method returns an ephemeral session
/// configuration as a workaround for a network request failure bug. See
/// https://developer.apple.com/forums/thread/777999 for details. For all other environments, the
/// default session configuration is returned.
+ (NSURLSessionConfiguration *)remoteConfigSessionConfiguration;

@end
