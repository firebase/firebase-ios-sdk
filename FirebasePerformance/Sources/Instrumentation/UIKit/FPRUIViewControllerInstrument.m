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

#import <TargetConditionals.h>
#import <UIKit/UIKit.h>

#import "FirebasePerformance/Sources/AppActivity/FPRScreenTraceTracker+Private.h"
#import "FirebasePerformance/Sources/Common/FPRDiagnostics.h"
#import "FirebasePerformance/Sources/Configurations/FPRConfigurations.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRClassInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRInstrument_Private.h"
#import "FirebasePerformance/Sources/Instrumentation/FPRSelectorInstrumentor.h"
#import "FirebasePerformance/Sources/Instrumentation/Network/FPRNetworkInstrumentHelpers.h"
#import "FirebasePerformance/Sources/Instrumentation/UIKit/FPRUIViewControllerInstrument.h"

#import <GoogleUtilities/GULAppEnvironmentUtil.h>
#import <GoogleUtilities/GULOriginalIMPConvenienceMacros.h>

/** Returns the dispatch queue for all instrumentation to occur on. */
static dispatch_queue_t GetInstrumentationQueue(void) {
  static dispatch_queue_t queue = nil;
  static dispatch_once_t token = 0;
  dispatch_once(&token, ^{
    queue = dispatch_queue_create("com.google.FPRUIViewControllerInstrumentation",
                                  DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

// Returns the singleton UIApplication of the application this is currently running in or nil if
// it's in an app extension.
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
static UIApplication *FPRSharedApplication(void) {
  if ([GULAppEnvironmentUtil isAppExtension]) {
    return nil;
  }
  return [UIApplication sharedApplication];
}

@implementation FPRUIViewControllerInstrument

/** Wraps -viewDidAppear:
 *
 *  @param instrument The FPRUIViewController instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentViewDidAppear(FPRUIViewControllerInstrument *instrument,
                             FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(viewDidAppear:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP oldViewDidAppearIMP = [selectorInstrumentor currentIMP];
  [selectorInstrumentor setReplacingBlock:^void(id _self, BOOL animated) {
    if (oldViewDidAppearIMP) {
      GUL_INVOKE_ORIGINAL_IMP1(_self, selector, void, oldViewDidAppearIMP, animated);
    }

    // This has to be called on the main thread and so it's done here instead of in
    // FPRScreenTraceTracker.
    if (FPRSharedApplication() && ((UIViewController *)_self).view.window.keyWindow) {
      [[FPRScreenTraceTracker sharedInstance] viewControllerDidAppear:_self];
    }
  }];
}

/** Wraps -viewDidDisappear:
 *
 *  @param instrument The FPRUIViewController instance.
 *  @param instrumentor The FPRClassInstrumentor to add the selector instrumentor to.
 */
FOUNDATION_STATIC_INLINE
NS_EXTENSION_UNAVAILABLE("Firebase Performance is not supported for extensions.")
void InstrumentViewDidDisappear(FPRUIViewControllerInstrument *instrument,
                                FPRClassInstrumentor *instrumentor) {
  SEL selector = @selector(viewDidDisappear:);
  FPRSelectorInstrumentor *selectorInstrumentor = SelectorInstrumentor(selector, instrumentor, NO);
  IMP oldViewDidDisappearIMP = [selectorInstrumentor currentIMP];
  [selectorInstrumentor setReplacingBlock:^void(id _self, BOOL animated) {
    if (oldViewDidDisappearIMP) {
      GUL_INVOKE_ORIGINAL_IMP1(_self, selector, void, oldViewDidDisappearIMP, animated);
    }
    [[FPRScreenTraceTracker sharedInstance] viewControllerDidDisappear:_self];
  }];
}

- (void)registerInstrumentors {
  dispatch_sync(GetInstrumentationQueue(), ^{
    FPRClassInstrumentor *instrumentor =
        [[FPRClassInstrumentor alloc] initWithClass:[UIViewController class]];

    if (![self registerClassInstrumentor:instrumentor]) {
      FPRAssert(NO, @"UIViewController should only be instrumented once.");
    }

    InstrumentViewDidAppear(self, instrumentor);
    InstrumentViewDidDisappear(self, instrumentor);

    [instrumentor swizzle];
  });
}

@end
