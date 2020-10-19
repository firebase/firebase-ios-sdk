/*
 * Copyright 2019 Google
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

typedef NS_ENUM(NSInteger, RCNDBSource) {
  RCNDBSourceActive,
  RCNDBSourceDefault,
  RCNDBSourceFetched,
};

@class RCNConfigDBManager;

/// This class handles all the config content that is fetched from the server, cached in local
/// config or persisted in database.
@interface RCNConfigContent : NSObject
/// Shared Singleton Instance
+ (instancetype)sharedInstance;

/// Fetched config (aka pending config) data that is latest data from server that might or might
/// not be applied.
@property(nonatomic, readonly, copy) NSDictionary *fetchedConfig;
/// Active config that is available to external users;
@property(nonatomic, readonly, copy) NSDictionary *activeConfig;
/// Local default config that is provided by external users;
@property(nonatomic, readonly, copy) NSDictionary *defaultConfig;

- (instancetype)init NS_UNAVAILABLE;

/// Designated initializer;
- (instancetype)initWithDBManager:(RCNConfigDBManager *)DBManager NS_DESIGNATED_INITIALIZER;

/// Returns true if initalization succeeded.
- (BOOL)initializationSuccessful;

/// Update config content from fetch response in JSON format.
- (void)updateConfigContentWithResponse:(NSDictionary *)response
                           forNamespace:(NSString *)FIRNamespace;

/// Copy from a given dictionary to one of the data source.
/// @param fromDictionary The data to copy from.
/// @param source       The data source to copy to(pending/active/default).
- (void)copyFromDictionary:(NSDictionary *)fromDictionary
                  toSource:(RCNDBSource)source
              forNamespace:(NSString *)FIRNamespace;

/// Sets the fetched Personalization metadata to active.
- (void)activatePersonalization;

/// Gets the active config and Personalization metadata.
- (NSDictionary *)getConfigAndMetadataForNamespace:(NSString *)FIRNamespace;

@end
