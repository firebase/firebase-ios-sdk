// Copyright 2022 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import <Foundation/Foundation.h>

@class FIRCLSMockFileManager;
@class FIRCLSMockSettings;

NS_ASSUME_NONNULL_BEGIN

/**
 Use this class to make FIRCLSContextInitialize if necessary.

 FIRCLSContextInitialize designed to be invoked once per app launch
 (e.g. we can't cancel _dyld_register_func_for_add_image)
 */
@interface FIRCLSSharedContext : NSObject

@property(nonatomic, readonly, strong) FIRCLSMockFileManager *fileManager;
@property(nonatomic, readonly, strong) FIRCLSMockSettings *mockSettings;
@property(nonatomic, readonly, strong) NSString *reportPath;

+ (instancetype)shared;

- (void)reset;

@end

NS_ASSUME_NONNULL_END
