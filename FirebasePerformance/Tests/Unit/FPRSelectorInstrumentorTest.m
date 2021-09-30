// Copyright 2020 Google LLC
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

#import <XCTest/XCTest.h>

#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"

/** A class used to test that swizzling init methods that funnel to the designated
 * initializer works as intended. */
@interface FPRFunneledInitTestClass : NSObject

@property(nonatomic) id object;

@end

@implementation FPRFunneledInitTestClass

- (instancetype)init {
  self = [self initWithObject:nil];
  return self;
}

- (instancetype)initWithObject:(id)object {
  self = [super init];
  if (self) {
    _object = object;
  }
  return self;
}

@end

@interface FPRSelectorInstrumentorTest : XCTestCase

@end

@implementation FPRSelectorInstrumentorTest

- (void)testInitWithSelector {
  FPRSelectorInstrumentor *instrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:@selector(description)
                                                  class:[NSObject class]
                                        isClassSelector:NO];
  XCTAssertNotNil(instrumentor);
}

#pragma mark - Unswizzle based tests

#ifndef SWIFT_PACKAGE

- (void)testInstanceMethodSwizzle {
  NSString *expectedDescription = @"Not the description you expected!";
  FPRSelectorInstrumentor *instrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:@selector(description)
                                                  class:[NSObject class]
                                        isClassSelector:NO];

  [instrumentor setReplacingBlock:^NSString *(id _self) {
    return expectedDescription;
  }];

  [instrumentor swizzle];
  NSString *returnedDescription = [[[NSObject alloc] init] description];
  XCTAssertEqualObjects(returnedDescription, expectedDescription);

  [instrumentor unswizzle];
}

- (void)testClassMethodSwizzle {
  NSString *expectedDescription = @"Not the description you expected!";
  FPRSelectorInstrumentor *instrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:@selector(description)
                                                  class:[NSObject class]
                                        isClassSelector:YES];

  [instrumentor setReplacingBlock:^NSString *(id _self) {
    return expectedDescription;
  }];

  [instrumentor swizzle];
  NSString *returnedDescription = [NSObject description];
  XCTAssertEqualObjects(returnedDescription, expectedDescription);

  [instrumentor unswizzle];
}

- (void)testInstanceMethodSwizzleWithOriginalImpInvocation {
  __block BOOL wasInvoked = NO;
  NSObject *object = [[NSObject alloc] init];
  NSString *originalDescription = [object description];
  SEL selector = @selector(description);
  Class instrumentedClass = [NSObject class];
  FPRSelectorInstrumentor *instrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:selector
                                                  class:instrumentedClass
                                        isClassSelector:NO];
  IMP originalIMP = instrumentor.currentIMP;
  [instrumentor setReplacingBlock:^NSString *(id _self) {
    wasInvoked = YES;
    typedef NSString *(*OriginalImp)(id, SEL);
    return ((OriginalImp)originalIMP)(_self, selector);
  }];

  [instrumentor swizzle];
  NSString *newDescription = [object description];

  XCTAssertTrue(wasInvoked);
  XCTAssertEqualObjects(newDescription, originalDescription);
  [instrumentor unswizzle];
}

- (void)testClassMethodSwizzleWithOriginalImpInvocation {
  __block BOOL wasInvoked = NO;
  NSString *originalDescription = [NSObject description];
  SEL selector = @selector(description);
  Class instrumentedClass = [NSObject class];
  FPRSelectorInstrumentor *instrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:selector
                                                  class:instrumentedClass
                                        isClassSelector:YES];
  IMP originalIMP = instrumentor.currentIMP;
  [instrumentor setReplacingBlock:^NSString *(id _self) {
    wasInvoked = YES;
    typedef NSString *(*OriginalImp)(id, SEL);
    return ((OriginalImp)originalIMP)(_self, selector);
  }];

  [instrumentor swizzle];
  NSString *newDescription = [NSObject description];

  XCTAssertTrue(wasInvoked);
  XCTAssertEqualObjects(newDescription, originalDescription);

  [instrumentor unswizzle];
}

- (void)testSwizzlingFunneledInstanceMethodsWithOriginalImpInvocation {
  __block BOOL initWasInvoked = NO;
  __block BOOL initWithObjectWasInvoked = NO;

  FPRSelectorInstrumentor *initInstrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:@selector(init)
                                                  class:[FPRFunneledInitTestClass class]
                                        isClassSelector:NO];
  FPRSelectorInstrumentor *initWithObjectInstrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:@selector(initWithObject:)
                                                  class:[FPRFunneledInitTestClass class]
                                        isClassSelector:NO];

  IMP originalIMPInit = initInstrumentor.currentIMP;
  IMP originalIMPInitWithObject = initWithObjectInstrumentor.currentIMP;

  [initInstrumentor setReplacingBlock:^id(id FPRFunneledInitTestClassInstance) {
    initWasInvoked = YES;
    typedef FPRFunneledInitTestClass *(*OriginalImp)(id, SEL);
    return ((OriginalImp)originalIMPInit)(FPRFunneledInitTestClassInstance, @selector(init));
  }];

  [initWithObjectInstrumentor
      setReplacingBlock:^id(id FPRFunneledInitTestClassInstance, id object) {
        initWithObjectWasInvoked = YES;
        typedef FPRFunneledInitTestClass *(*OriginalImp)(id, SEL, id);
        return ((OriginalImp)originalIMPInitWithObject)(FPRFunneledInitTestClassInstance,
                                                        @selector(initWithObject:), @(1));
      }];

  [initInstrumentor swizzle];
  [initWithObjectInstrumentor swizzle];

  FPRFunneledInitTestClass *object1 = [[FPRFunneledInitTestClass alloc] init];
  XCTAssertTrue(initWasInvoked);
  XCTAssertTrue(initWithObjectWasInvoked);
  XCTAssertNotNil(object1);
  FPRFunneledInitTestClass *object2 = [[FPRFunneledInitTestClass alloc] initWithObject:@(3)];
  XCTAssertNotNil(object2);

  [initInstrumentor unswizzle];
  [initWithObjectInstrumentor unswizzle];
}

/** Tests that the init method of an object is swizzleable. For ARC-related reasons, init and new
 *  cannot be swizzled without invoking the original selector.
 */
- (void)testThatInitIsSwizzleable {
  SEL selector = @selector(init);
  Class instrumentedClass = [FPRFunneledInitTestClass class];
  FPRSelectorInstrumentor *instrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:selector
                                                  class:instrumentedClass
                                        isClassSelector:NO];
  IMP originalIMP = instrumentor.currentIMP;
  __block BOOL wasInvoked = NO;
  [instrumentor setReplacingBlock:^id(id _objectInstance) {
    wasInvoked = YES;
    typedef NSObject *(*OriginalImp)(id, SEL);
    return ((OriginalImp)originalIMP)(_objectInstance, selector);
  }];
  [instrumentor swizzle];
  NSObject *object = [[FPRFunneledInitTestClass alloc] init];
  XCTAssertNotNil(object);
  XCTAssertTrue(wasInvoked);
  [instrumentor unswizzle];
}

/** Tests that swizzling a subclass of a class cluster works properly.
 *
 *  If the subclass of a class cluster's superclass is swizzled after the superclass and the
 *  subclass doesn't provide a concrete implementation of method, the method obtained by the runtime
 *  will find the already-swizzled superclass method. In this case, the method that existed *before*
 *  swizzling the superclass method should be returned. The reason is that the
 *  FPRSelectorInstrumentor may die while the swizzled IMP lives on. If a subclass captures the
 *  now-dead FPRSelectorInstrumentor's IMP as the "original" IMP, then this will cause a
 *  null-pointer dereference when a call-through is attempted. To resolve this, a mapping of
 *  new->original IMPs must be maintained, and if the "original" IMP ends up actually being one of
 *  our swizzled IMPs, we should instead return the IMP that existed before.
 */
- (void)testSwizzlingSubclassOfClassClusterAfterSuperclassCallsNonSwizzledImp {
  // A typedef that wraps the completion handler type.
  typedef void (^DataTaskCompletionHandler)(NSData *_Nullable, NSURLResponse *_Nullable,
                                            NSError *_Nullable);

  NSMutableArray<FPRSelectorInstrumentor *> *superclassInstrumentors =
      [[NSMutableArray alloc] init];
  NSMutableArray<FPRSelectorInstrumentor *> *subclassInstrumentors = [[NSMutableArray alloc] init];

  Class superclass = [NSURLSession class];
  Class subclass = [[NSURLSession sharedSession] class];
  XCTAssertNotEqual(superclass, subclass);

  SEL currentSelector = nil;
  FPRSelectorInstrumentor *currentInstrumentor = nil;

  // Swizzle the superclass selector.
  currentSelector = @selector(dataTaskWithRequest:);
  currentInstrumentor = [[FPRSelectorInstrumentor alloc] initWithSelector:currentSelector
                                                                    class:superclass
                                                          isClassSelector:NO];
  IMP originalIMP = currentInstrumentor.currentIMP;
  [currentInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    return ((OriginalImp)originalIMP)(session, currentSelector, request);
  }];
  [superclassInstrumentors addObject:currentInstrumentor];

  currentSelector = @selector(dataTaskWithRequest:completionHandler:);
  currentInstrumentor = [[FPRSelectorInstrumentor alloc] initWithSelector:currentSelector
                                                                    class:superclass
                                                          isClassSelector:NO];
  originalIMP = currentInstrumentor.currentIMP;
  [currentInstrumentor setReplacingBlock:^(id session, NSURLRequest *request,
                                           DataTaskCompletionHandler completionHandler) {
    DataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *,
                                                 DataTaskCompletionHandler);
    return ((OriginalImp)originalIMP)(session, currentSelector, request, wrappedCompletionHandler);
  }];
  [superclassInstrumentors addObject:currentInstrumentor];

  // Swizzle the subclass selectors.
  currentSelector = @selector(dataTaskWithRequest:);
  currentInstrumentor = [[FPRSelectorInstrumentor alloc] initWithSelector:currentSelector
                                                                    class:subclass
                                                          isClassSelector:NO];
  originalIMP = currentInstrumentor.currentIMP;
  [currentInstrumentor setReplacingBlock:^(id session, NSURLRequest *request) {
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *);
    return ((OriginalImp)originalIMP)(session, currentSelector, request);
  }];
  [subclassInstrumentors addObject:currentInstrumentor];

  currentSelector = @selector(dataTaskWithRequest:completionHandler:);
  currentInstrumentor = [[FPRSelectorInstrumentor alloc] initWithSelector:currentSelector
                                                                    class:subclass
                                                          isClassSelector:NO];
  originalIMP = currentInstrumentor.currentIMP;
  [currentInstrumentor setReplacingBlock:^(id session, NSURLRequest *request,
                                           DataTaskCompletionHandler completionHandler) {
    DataTaskCompletionHandler wrappedCompletionHandler = nil;
    if (completionHandler) {
      wrappedCompletionHandler = ^(NSData *data, NSURLResponse *response, NSError *error) {
        completionHandler(data, response, error);
      };
    }
    typedef NSURLSessionDataTask *(*OriginalImp)(id, SEL, NSURLRequest *,
                                                 DataTaskCompletionHandler);
    return ((OriginalImp)originalIMP)(session, currentSelector, request, wrappedCompletionHandler);
  }];
  [subclassInstrumentors addObject:currentInstrumentor];

  for (FPRSelectorInstrumentor *superclassInstrumentor in superclassInstrumentors) {
    [superclassInstrumentor swizzle];
  }
  for (FPRSelectorInstrumentor *subclassInstrumentor in subclassInstrumentors) {
    [subclassInstrumentor swizzle];
  }
  for (FPRSelectorInstrumentor *superclassInstrumentor in superclassInstrumentors) {
    [superclassInstrumentor unswizzle];
  }
  [superclassInstrumentors removeAllObjects];
  superclassInstrumentors = nil;

  NSURL *url = [NSURL URLWithString:@"https://abc.xyz"];
  __block BOOL completionHandlerCalled = NO;
  void (^completionHandler)(NSData *_Nullable, NSURLResponse *_Nullable, NSError *_Nullable) =
      ^(NSData *_Nullable data, NSURLResponse *_Nullable response, NSError *_Nullable error) {
        completionHandlerCalled = YES;
      };
  NSURLSessionDataTask *session = [[NSURLSession sharedSession] dataTaskWithURL:url
                                                              completionHandler:completionHandler];
  XCTAssertNotNil(session);
  for (FPRSelectorInstrumentor *subclassInstrumentor in subclassInstrumentors) {
    [subclassInstrumentor unswizzle];
  }
}

#endif  // SWIFT_PACKAGE

/** Tests attempting to swizzle non-existent/unimplemented method (like @dynamic) returns nil. */
- (void)testNonexistentMethodReturnsNil {
  FPRSelectorInstrumentor *instrumentor =
      [[FPRSelectorInstrumentor alloc] initWithSelector:NSSelectorFromString(@"randomMethod")
                                                  class:[NSURLSession class]
                                        isClassSelector:NO];
  XCTAssertNil(instrumentor);
  [instrumentor unswizzle];
}

@end
