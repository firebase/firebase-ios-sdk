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

@class FIRComponentContainer;
@class FIRFakeOptions;

@interface FIRFakeApp : NSObject

- (instancetype)initWithName:(NSString *)name URL:(NSString *_Nullable)url;

@property(nonatomic, readonly) FIRFakeOptions *options;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, readonly) FIRComponentContainer *container;
@end

NS_ASSUME_NONNULL_END
