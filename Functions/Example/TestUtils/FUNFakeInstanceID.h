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

/**
 * This FIRInstanceID is a mock instance ID provider to use for tests.
 * Since FirebaseFunctions loads FIRInstanceID as a weak dependency by reflection, we just have to
 * make a class with the same name.
 */
@interface FIRInstanceID : NSObject

+ (instancetype)instanceID;

- (NSString *)token;

@end

NS_ASSUME_NONNULL_END
