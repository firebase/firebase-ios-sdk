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

// Note: This file is forked from FIRMessagingInstanceIDProxy.h

#import <Foundation/Foundation.h>

/**
 *  FirebaseFunctions cannot always depend on FIRInstanceID directly, due to how it is
 *  packaged. To make it easier to make calls to FIRInstanceID, this proxy class, will provide
 *  method names duplicated from FIRInstanceID, while using reflection-based called to proxy
 *  the requests.
 */
@interface FUNInstanceIDProxy : NSObject
- (nullable NSString *)token;
@end
