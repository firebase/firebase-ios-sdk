//
//  FIRFirebaseUserAgent.m
//  Pods
//
//  Created by Maksym Malyhin on 2020-09-09.
//

#import "FirebaseCore/Sources/FIRFirebaseUserAgent.h"

#import "FirebaseCore/Sources/Private/FIRAppInternal.h"

#import <objc/runtime.h>

static NSString *const kApplePlatformComponentName = @"apple-platform";

@interface FIRFirebaseUserAgent ()

@property(nonatomic, readonly) NSMutableDictionary<NSString *, NSString *> *valuesByComponent;
@property(nonatomic, readonly) NSString *firebaseUserAgent;

@end

@implementation FIRFirebaseUserAgent

@synthesize firebaseUserAgent = _firebaseUserAgent;

- (instancetype)init {
  self = [super init];
  if (self) {
    _valuesByComponent = [[[self class] environmentComponents] mutableCopy];
  }
  return self;
}

- (NSString *)firebaseUserAgent {
  @synchronized(self) {
    if (_firebaseUserAgent == nil) {
      __block NSMutableArray<NSString *> *components =
          [[NSMutableArray<NSString *> alloc] initWithCapacity:self.valuesByComponent.count];
      [self.valuesByComponent
          enumerateKeysAndObjectsUsingBlock:^(NSString *_Nonnull name, NSString *_Nonnull value,
                                              BOOL *_Nonnull stop) {
            [components addObject:[NSString stringWithFormat:@"%@/%@", name, value]];
          }];
      [components sortUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
      _firebaseUserAgent = [components componentsJoinedByString:@" "];
    }
    return _firebaseUserAgent;
  }
}

- (void)setValue:(NSString *)value forComponent:(NSString *)componentName {
  @synchronized(self) {
    self.valuesByComponent[componentName] = value;
    // Reset cached user agent string.
    _firebaseUserAgent = nil;
  }
}

- (void)reset {
  @synchronized(self) {
    // Reset components.
    _valuesByComponent = [[[self class] environmentComponents] mutableCopy];
    // Reset cached user agent string.
    _firebaseUserAgent = nil;
  }
}

#pragma mark - Environment components

+ (NSDictionary<NSString *, NSString *> *)environmentComponents {
  NSDictionary<NSString *, id> *info = [[NSBundle mainBundle] infoDictionary];
  NSString *xcodeVersion = info[@"DTXcodeBuild"];
  NSString *sdkVersion = info[@"DTSDKBuild"];

  NSString *swiftFlagValue = [self hasSwiftRuntime] ? @"true" : @"false";

  return @{
    @"xcode" : xcodeVersion,
    @"apple-sdk" : sdkVersion,
    @"swift" : swiftFlagValue,
    @"apple-platform" : [self applePlatform]
  };
}

+ (BOOL)hasSwiftRuntime {
  // The class
  // [Swift._SwiftObject](https://github.com/apple/swift/blob/5eac3e2818eb340b11232aff83edfbd1c307fa03/stdlib/public/runtime/SwiftObject.h#L35)
  // is a part of Swift runtime, so it should be present if Swift runtime is available.

  BOOL hasSwiftRuntime =
      objc_lookUpClass("Swift._SwiftObject") != nil ||
      // Swift object class name before
      // https://github.com/apple/swift/commit/9637b4a6e11ddca72f5f6dbe528efc7c92f14d01
      objc_getClass("_TtCs12_SwiftObject") != nil;

  return hasSwiftRuntime;
}

+ (NSString *)applePlatform {
  NSString *applePlatform = @"unknown";

  // When a Catalyst app is run on macOS then both `TARGET_OS_MACCATALYST` and `TARGET_OS_IOS` are
  // `true`, which means the condition list is order-sensitive.
#if TARGET_OS_MACCATALYST
  applePlatform = @"maccatalyst";
#elif TARGET_OS_IOS
  applePlatform = @"ios";
#elif TARGET_OS_TV
  applePlatform = @"tvos";
#elif TARGET_OS_OSX
  applePlatform = @"macos";
#elif TARGET_OS_WATCH
  applePlatform = @"watchos";
#endif

  return applePlatform;
}

@end
