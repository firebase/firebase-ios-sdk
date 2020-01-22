/*
 * Copyright 2017 Google
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

// A class that will persist response data fetched from server side into a local file on
// client side. This file can be used as the cache for messages after the app has been
// killed and before it's up for next server fetch.
@interface FIRIAMServerMsgFetchStorage : NSObject
- (void)saveResponseDictionary:(NSDictionary *)response
                withCompletion:(void (^)(BOOL success))completion;
- (void)readResponseDictionary:(void (^)(NSDictionary *response, BOOL success))completion;

@end
NS_ASSUME_NONNULL_END
