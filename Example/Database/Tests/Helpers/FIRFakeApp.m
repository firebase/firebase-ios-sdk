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

#import "FIRFakeApp.h"

@interface FIRFakeOptions: NSObject
@property(nonatomic, readonly, copy) NSString *databaseURL;
- (instancetype) initWithURL:(NSString *)url;
@end

@implementation FIRFakeOptions
- (instancetype) initWithURL:(NSString *)url {
    self = [super init];
    if (self) {
        self->_databaseURL = url;
    }
    return self;
}
@end

@implementation FIRFakeApp

- (instancetype) initWithName:(NSString *)name URL:(NSString *)url {
    self = [super init];
    if (self) {
        self->_name = name;
        self->_options = [[FIRFakeOptions alloc] initWithURL:url];
    }
    return self;
}

- (void)getTokenForcingRefresh:(BOOL)forceRefresh withCallback:(void (^)(NSString *_Nullable token, NSError *_Nullable error))callback {
    callback(nil, nil);
}
@end
