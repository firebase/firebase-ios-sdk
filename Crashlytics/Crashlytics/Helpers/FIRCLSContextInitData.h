// Copyright 2023 Google
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

#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FIRCLSContextInitData : NSObject

@property(nonatomic, copy, nullable) NSString* customBundleId;
@property(nonatomic, copy) NSString* rootPath;
@property(nonatomic, copy) NSString* previouslyCrashedFileRootPath;
@property(nonatomic, copy) NSString* sessionId;
@property(nonatomic, copy) NSString* appQualitySessionId;
@property(nonatomic, copy) NSString* betaToken;
@property(nonatomic) BOOL errorsEnabled;
@property(nonatomic) BOOL customExceptionsEnabled;
@property(nonatomic) uint32_t maxCustomExceptions;
@property(nonatomic) uint32_t maxErrorLogSize;
@property(nonatomic) uint32_t maxLogSize;
@property(nonatomic) uint32_t maxKeyValues;

@end

NS_ASSUME_NONNULL_END
