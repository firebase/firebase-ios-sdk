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

#import "FirebaseDatabase/Sources/Core/FQueryParams.h"
#import "FirebaseDatabase/Sources/Utilities/FTypedefs.h"
#import <Foundation/Foundation.h>

@interface FTupleUserCallback : NSObject

- (id)initWithHandle:(NSUInteger)handle;

@property(nonatomic, copy)
    fbt_void_datasnapshot_nsstring datasnapshotPrevnameCallback;
@property(nonatomic, copy) fbt_void_datasnapshot datasnapshotCallback;
@property(nonatomic, copy) fbt_void_nserror cancelCallback;
@property(nonatomic, copy) FQueryParams *queryParams;
@property(nonatomic) NSUInteger handle;

@end
