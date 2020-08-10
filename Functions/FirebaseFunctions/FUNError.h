//
// Copyright 2017 Google
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
#import "Functions/FirebaseFunctions/Public/FirebaseFunctions/FIRError.h"

@class FUNSerializer;

NS_ASSUME_NONNULL_BEGIN

/**
 * Takes an error code and returns a corresponding NSError.
 * @param code The eror code.
 * @return The corresponding NSError.
 */
NSError *_Nullable FUNErrorForCode(FIRFunctionsErrorCode code);

/**
 * Takes an HTTP status code and optional body and returns a corresponding NSError.
 * If an explicit error is encoded in the JSON body, it will be used.
 * Otherwise, uses the standard HTTP status code -> error mapping defined in:
 * https://github.com/googleapis/googleapis/blob/master/google/rpc/code.proto
 * @param status An HTTP status code.
 * @param body Optional body of the HTTP response.
 * @param serializer A serializer to use to decode the details in the error response.
 * @return The corresponding error.
 */
NSError *_Nullable FUNErrorForResponse(NSInteger status,
                                       NSData *_Nullable body,
                                       FUNSerializer *serializer);

NS_ASSUME_NONNULL_END
