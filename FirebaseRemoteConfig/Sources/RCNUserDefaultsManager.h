#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface RCNUserDefaultsManager : NSObject

/// The last eTag received from the backend.
@property(nonatomic) NSString *lastETag;
/// The time of the last successful fetch.
@property(nonatomic, assign) NSTimeInterval lastFetchTime;
/// The time of the last successful fetch.
@property(nonatomic) NSString *lastFetchStatus;
/// Boolean indicating if the last (one or more) fetch(es) was/were unsuccessful, in which case we
/// are in an exponential backoff mode.
@property(nonatomic, assign) BOOL isClientThrottledWithExponentialBackoff;
/// Time when the next request can be made while being throttled.
@property(nonatomic, assign) NSTimeInterval throttleEndTime;
/// The retry interval increases exponentially for cumulative fetch failures. Refer to
/// go/rc-client-throttling for details.
@property(nonatomic, assign) NSTimeInterval currentThrottlingRetryIntervalSeconds;
/// The version of the Remote Config database. Any changes to database schema should increment this
/// version.
@property(nonatomic) NSNumber *databaseVersion;

/// Designated initializer.
- (instancetype)initWithAppName:(NSString *)appName
                       bundleID:(NSString *)bundleIdentifier
                      namespace:(NSString *)firebaseNamespace NS_DESIGNATED_INITIALIZER;


// NOLINTBEGIN
/// Use `initWithAppName:bundleID:namespace:` instead.
- (instancetype)init __attribute__((unavailable("Use `initWithAppName:bundleID:namespace:` instead.")));
// NOLINTEND

+ (instancetype)sharedInstanceForDefaultAppAndNamespace;
@end

NS_ASSUME_NONNULL_END
