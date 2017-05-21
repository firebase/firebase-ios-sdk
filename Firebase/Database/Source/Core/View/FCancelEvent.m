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

#import "FCancelEvent.h"
#import "FPath.h"
#import "FEventRegistration.h"

@interface FCancelEvent ()
@property (nonatomic, strong) id<FEventRegistration> eventRegistration;
@property (nonatomic, strong, readwrite) NSError *error;
@property (nonatomic, strong, readwrite) FPath *path;
@end

@implementation FCancelEvent

@synthesize eventRegistration;
@synthesize error;
@synthesize path;

- (id)initWithEventRegistration:(id <FEventRegistration>)registration error:(NSError *)anError path:(FPath *)aPath {
    self = [super init];
    if (self) {
        self.eventRegistration = registration;
        self.error = anError;
        self.path = aPath;
    }
    return self;
}

- (void) fireEventOnQueue:(dispatch_queue_t)queue {
    [self.eventRegistration fireEvent:self queue:queue];
}

- (BOOL) isCancelEvent {
    return YES;
}

- (NSString *) description {
    return [NSString stringWithFormat:@"%@: cancel", self.path];
}

@end
