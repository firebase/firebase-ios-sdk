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

#ifndef Firebase_FTypedefs_h
#define Firebase_FTypedefs_h

/**
 * Stub...
 */
@class FIRDataSnapshot;
@class FIRDatabaseReference;
@class FAuthData;
@protocol FNode;

// fbt = Firebase Block Typedef

typedef void (^fbt_void_void)(void);
typedef void (^fbt_void_datasnapshot_nsstring)(FIRDataSnapshot *snapshot,
                                               NSString *prevName);
typedef void (^fbt_void_datasnapshot)(FIRDataSnapshot *snapshot);
typedef void (^fbt_void_user)(FAuthData *user);
typedef void (^fbt_void_nsstring_id)(NSString *status, id data);
typedef void (^fbt_void_nserror_id)(NSError *error, id data);
typedef void (^fbt_void_nserror)(NSError *error);
typedef void (^fbt_void_nserror_ref)(NSError *error, FIRDatabaseReference *ref);
typedef void (^fbt_void_nserror_user)(NSError *error, FAuthData *user);
typedef void (^fbt_void_nserror_json)(NSError *error, NSDictionary *json);
typedef void (^fbt_void_nsdictionary)(NSDictionary *data);
typedef id (^fbt_id_node_nsstring)(id<FNode> node, NSString *childName);

#endif
