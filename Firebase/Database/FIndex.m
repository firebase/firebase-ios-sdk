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

#import "FIndex.h"

#import "FKeyIndex.h"
#import "FPathIndex.h"
#import "FPriorityIndex.h"
#import "FValueIndex.h"

@implementation FIndex

+ (id<FIndex>)indexFromQueryDefinition:(NSString *)string {
    if ([string isEqualToString:@".key"]) {
        return [FKeyIndex keyIndex];
    } else if ([string isEqualToString:@".value"]) {
        return [FValueIndex valueIndex];
    } else if ([string isEqualToString:@".priority"]) {
        return [FPriorityIndex priorityIndex];
    } else {
        return
            [[FPathIndex alloc] initWithPath:[[FPath alloc] initWith:string]];
    }
}

@end
