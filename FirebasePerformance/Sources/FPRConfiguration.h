// Copyright 2020 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

/**
 * @brief Configures the behavior of FPR.
 */
@interface FPRConfiguration : NSObject <NSCopying>

/**
 * Designated initializer.
 * @brief Creates a new configuration.
 *
 * @param appID Identifies app on Firebase
 * @param APIKey Authenticates app on Firebase
 * @param autoPush Google Data Transport destination - prod/autopush
 */
- (instancetype)initWithAppID:(NSString *)appID
                       APIKey:(NSString *)APIKey
                     autoPush:(BOOL)autoPush NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/** This is a class method for initWithAppID:APIKey:autoPush:. */
+ (instancetype)configurationWithAppID:(NSString *)appID
                                APIKey:(NSString *)APIKey
                              autoPush:(BOOL)autoPush;

/** @brief Identifies app on Firebase. */
@property(readonly, nonatomic, copy) NSString *appID;

/** @brief Authenticates app on Firebase. */
@property(readonly, nonatomic, copy) NSString *APIKey;

/** @brief Use autopush or prod logging. */
@property(readonly, nonatomic, assign, getter=isAutoPush) BOOL autoPush;

@end
