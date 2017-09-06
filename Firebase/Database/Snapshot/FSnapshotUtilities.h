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

#import "FNode.h"
#import <Foundation/Foundation.h>

@class FImmutableSortedDictionary;
@class FCompoundWrite;
@class FLeafNode;
@protocol FNode;

typedef NS_ENUM(NSInteger, FDataHashVersion) {
    FDataHashVersionV1,
    FDataHashVersionV2,
};

@interface FSnapshotUtilities : NSObject

+ (id<FNode>)nodeFrom:(id)val;
+ (id<FNode>)nodeFrom:(id)val priority:(id)priority;
+ (id<FNode>)nodeFrom:(id)val withValidationFrom:(NSString *)fn;
+ (id<FNode>)nodeFrom:(id)val
              priority:(id)priority
    withValidationFrom:(NSString *)fn;
+ (FCompoundWrite *)compoundWriteFromDictionary:(NSDictionary *)values
                             withValidationFrom:(NSString *)fn;
+ (void)validatePriorityNode:(id<FNode>)priorityNode;
+ (void)appendHashRepresentationForLeafNode:(FLeafNode *)val
                                   toString:(NSMutableString *)string
                                hashVersion:(FDataHashVersion)hashVersion;
+ (void)appendHashV2RepresentationForString:(NSString *)string
                                   toString:(NSMutableString *)mutableString;

+ (NSUInteger)estimateSerializedNodeSize:(id<FNode>)node;

@end
