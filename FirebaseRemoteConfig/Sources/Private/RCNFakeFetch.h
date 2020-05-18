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

#import <Foundation/Foundation.h>

/// Enables RemoteConfig testing without a networked backend by providing a fake RemoteConfig.
NS_SWIFT_NAME(FakeFetch)
@interface RCNFakeFetch : NSObject

/// Holds the current fake config.
@property(class, nonatomic, copy) NSMutableDictionary<NSString *, id> *config;

/// Returns the config and additional metadata.
+ (NSDictionary<NSString *, id> *)get;

/// If the Fake Fetcher is activated.
+ (BOOL)active;
@end
