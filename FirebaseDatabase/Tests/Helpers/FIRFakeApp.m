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

#import "FirebaseDatabase/Tests/Helpers/FIRFakeApp.h"

#import "FirebaseDatabase/Sources/Api/FIRDatabaseComponent.h"
#import "SharedTestUtilities/FIRAuthInteropFake.h"
#import "SharedTestUtilities/FIRComponentTestUtilities.h"

@interface FIRFakeOptions : NSObject
@property(nonatomic, readonly, copy) NSString *_Nullable databaseURL;
@property(nonatomic, readonly, copy) NSString *projectID;
@property(nonatomic, readonly, copy) NSString *googleAppID;
- (instancetype)initWithURL:(NSString *_Nullable)url;
@end

@implementation FIRFakeOptions
- (instancetype)initWithURL:(NSString *_Nullable)url {
  self = [super init];
  if (self) {
    _databaseURL = url;
    _googleAppID = @"fake-app-id";
    _projectID = @"fake-project-id";
  }
  return self;
}
@end

@interface FIRDatabaseComponent (Internal)
- (instancetype)initWithApp:(FIRApp *)app;
@end

@interface FIRComponentContainer (TestInternal)
@property(nonatomic, strong) NSMutableDictionary<NSString *, FIRComponentCreationBlock> *components;
@end

@interface FIRComponentContainer (TestInternalImplementations)
- (instancetype)initWithApp:(FIRApp *)app
                 components:(NSDictionary<NSString *, FIRComponentCreationBlock> *)components;
@end

@implementation FIRComponentContainer (TestInternalImplementations)

- (instancetype)initWithApp:(FIRApp *)app
                 components:(NSDictionary<NSString *, FIRComponentCreationBlock> *)components {
  self = [self initWithApp:app registrants:[[NSMutableSet alloc] init]];
  if (self) {
    self.components = [components mutableCopy];
  }
  return self;
}
@end

@implementation FIRFakeApp

- (instancetype)initWithName:(NSString *)name URL:(NSString *_Nullable)url {
  self = [super init];
  if (self) {
    _name = name;
    _options = [[FIRFakeOptions alloc] initWithURL:url];
    _Nullable id (^authBlock)(FIRComponentContainer *, BOOL *) =
        ^(FIRComponentContainer *container, BOOL *isCacheable) {
          return [[FIRAuthInteropFake alloc] initWithToken:nil userID:nil error:nil];
        };
    FIRComponentCreationBlock databaseBlock =
        ^id _Nullable(FIRComponentContainer *container, BOOL *isCacheable) {
      *isCacheable = YES;
      return [[FIRDatabaseComponent alloc] initWithApp:container.app];
    };
    NSDictionary<NSString *, FIRComponentCreationBlock> *components = @{
      NSStringFromProtocol(@protocol(FIRAuthInterop)) : authBlock,
      NSStringFromProtocol(@protocol(FIRDatabaseProvider)) : databaseBlock
    };
    _container = [[FIRComponentContainer alloc] initWithApp:(FIRApp *)self components:components];
  }
  return self;
}
@end
