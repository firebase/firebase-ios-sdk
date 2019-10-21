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

NS_ASSUME_NONNULL_BEGIN

/// Helper functions to access Keychain.
@interface FIRInstallationsKeychainUtils : NSObject

+ (nullable NSData *)getItemWithQuery:(NSDictionary *)query
                                error:(NSError *_Nullable *_Nullable)outError;

+ (BOOL)setItem:(NSData *)item
      withQuery:(NSDictionary *)query
          error:(NSError *_Nullable *_Nullable)outError;

+ (BOOL)removeItemWithQuery:(NSDictionary *)query error:(NSError *_Nullable *_Nullable)outError;

@end

NS_ASSUME_NONNULL_END
