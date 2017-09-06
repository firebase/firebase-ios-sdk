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

#import "FTypedefs_Private.h"

@class FQuerySpec;
@protocol FSyncTreeHash;

typedef NSArray * (^fbt_startListeningBlock)(FQuerySpec *query, NSNumber *tagId,
                                             id<FSyncTreeHash> hash,
                                             fbt_nsarray_nsstring onComplete);
typedef void (^fbt_stopListeningBlock)(FQuerySpec *query, NSNumber *tagId);

@interface FListenProvider : NSObject

@property(nonatomic, copy) fbt_startListeningBlock startListening;
@property(nonatomic, copy) fbt_stopListeningBlock stopListening;

@end
