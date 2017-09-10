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

@protocol FIndex
, FNodeFilter, FNode;

@interface FQueryParams : NSObject <NSCopying>

@property(nonatomic, readonly) BOOL limitSet;
@property(nonatomic, readonly) NSInteger limit;

@property(nonatomic, strong, readonly) NSString *viewFrom;
@property(nonatomic, strong, readonly) id<FNode> indexStartValue;
@property(nonatomic, strong, readonly) NSString *indexStartKey;
@property(nonatomic, strong, readonly) id<FNode> indexEndValue;
@property(nonatomic, strong, readonly) NSString *indexEndKey;

@property(nonatomic, strong, readonly) id<FIndex> index;

- (BOOL)loadsAllData;
- (BOOL)isDefault;
- (BOOL)isValid;
- (BOOL)hasAnchoredLimit;

- (FQueryParams *)limitTo:(NSInteger)limit;
- (FQueryParams *)limitToFirst:(NSInteger)newLimit;
- (FQueryParams *)limitToLast:(NSInteger)newLimit;

- (FQueryParams *)startAt:(id<FNode>)indexValue childKey:(NSString *)key;
- (FQueryParams *)startAt:(id<FNode>)indexValue;
- (FQueryParams *)endAt:(id<FNode>)indexValue childKey:(NSString *)key;
- (FQueryParams *)endAt:(id<FNode>)indexValue;

- (FQueryParams *)orderBy:(id<FIndex>)index;

+ (FQueryParams *)defaultInstance;
+ (FQueryParams *)fromQueryObject:(NSDictionary *)dict;

- (BOOL)hasStart;
- (BOOL)hasEnd;

- (NSDictionary *)wireProtocolParams;
- (BOOL)isViewFromLeft;
- (id<FNodeFilter>)nodeFilter;
@end
