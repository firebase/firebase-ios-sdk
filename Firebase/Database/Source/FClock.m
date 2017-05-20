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

#import "FClock.h"

@implementation FSystemClock

- (NSTimeInterval)currentTime {
    return [[NSDate date] timeIntervalSince1970];
}

+ (FSystemClock *)clock {
    static dispatch_once_t onceToken;
    static FSystemClock *clock;
    dispatch_once(&onceToken, ^{
        clock = [[FSystemClock alloc] init];
    });
    return clock;
}

@end

@interface FOffsetClock ()

@property (nonatomic, strong) id<FClock> clock;
@property (nonatomic) NSTimeInterval offset;

@end

@implementation FOffsetClock

- (NSTimeInterval)currentTime {
    return [self.clock currentTime] + self.offset;
}

- (id)initWithClock:(id<FClock>)clock offset:(NSTimeInterval)offset {
    self = [super init];
    if (self != nil) {
        self->_clock = clock;
        self->_offset = offset;
    }
    return self;
}

@end
