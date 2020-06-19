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

#import "FirebaseDatabase/Sources/Utilities/FAtomicNumber.h"

@interface FAtomicNumber () {
    unsigned long number;
}

@property(nonatomic, strong) NSLock *lock;

@end

@implementation FAtomicNumber

@synthesize lock;

- (id)init {
    self = [super init];
    if (self) {
        number = 1;
        self.lock = [[NSLock alloc] init];
    }
    return self;
}

- (NSNumber *)getAndIncrement {
    NSNumber *result;

    // See:
    // http://developer.apple.com/library/ios/#DOCUMENTATION/Cocoa/Conceptual/Multithreading/ThreadSafety/ThreadSafety.html#//apple_ref/doc/uid/10000057i-CH8-SW14
    // to improve, etc.

    [self.lock lock];
    result = [NSNumber numberWithUnsignedLong:number];
    number = number + 1;
    [self.lock unlock];

    return result;
}

@end
