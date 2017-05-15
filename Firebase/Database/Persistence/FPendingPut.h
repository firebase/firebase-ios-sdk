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
#import "FPath.h"

// These are all legacy classes and are used to migrate older persistence data base to newer ones
// These classes should not be used in newer code

@interface FPendingPut : NSObject<NSCoding>

@property (nonatomic, strong) FPath* path;
@property (nonatomic, strong) id data;
@property (nonatomic, strong) id priority;

- (id) initWithPath:(FPath*)aPath andData:(id)aData andPriority:aPriority;
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;
@end


@interface FPendingPutPriority : NSObject<NSCoding>

@property (nonatomic, strong) FPath* path;
@property (nonatomic, strong) id priority;

- (id) initWithPath:(FPath*)aPath andPriority:(id)aPriority;
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;

@end


@interface FPendingUpdate : NSObject<NSCoding>

@property (nonatomic, strong) FPath* path;
@property (nonatomic, strong) NSDictionary* data;

- (id) initWithPath:(FPath*)aPath andData:(NSDictionary*)aData;
- (void)encodeWithCoder:(NSCoder *)aCoder;
- (id)initWithCoder:(NSCoder *)aDecoder;
@end
