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

#import "FirebaseDatabase/Sources/Public/FirebaseDatabase/FIRTransactionResult.h"
#import "FirebaseDatabase/Sources/Api/Private/FIRTransactionResult_Private.h"

@implementation FIRTransactionResult

@synthesize update;
@synthesize isSuccess;

+ (FIRTransactionResult *)successWithValue:(FIRMutableData *)value {
    FIRTransactionResult *result = [[FIRTransactionResult alloc] init];
    result.isSuccess = YES;
    result.update = value;
    return result;
}

+ (FIRTransactionResult *)abort {
    FIRTransactionResult *result = [[FIRTransactionResult alloc] init];
    result.isSuccess = NO;
    result.update = nil;
    return result;
}

@end
