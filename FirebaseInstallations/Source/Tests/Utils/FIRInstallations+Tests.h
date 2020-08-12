/*
 * Copyright 2019 Google
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
#import "FirebaseInstallations/Source/Library/Public/FirebaseInstallations/FIRInstallations.h"

@class FIRInstallationsIDController;
@class FIROptions;

NS_ASSUME_NONNULL_BEGIN

@interface FIRInstallations (Tests)
@property(nonatomic, readwrite, strong) FIROptions *appOptions;
@property(nonatomic, readwrite, strong) NSString *appName;

- (instancetype)initWithAppOptions:(FIROptions *)appOptions
                           appName:(NSString *)appName
         installationsIDController:(FIRInstallationsIDController *)installationsIDController
                 prefetchAuthToken:(BOOL)prefetchAuthToken;

@end
NS_ASSUME_NONNULL_END
