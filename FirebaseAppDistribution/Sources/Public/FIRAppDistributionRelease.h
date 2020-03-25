#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * The release information returned by the update check when a new version is available.
 */
NS_SWIFT_NAME(AppDistributionRelease)
@interface FIRAppDistributionRelease : NSObject

// The short bundle version of this build (example 1.0.0)
@property(nonatomic, copy) NSString *displayVersion;

// The build number of this build (example: 123)
@property(nonatomic, copy) NSString *buildVersion;

// The release notes for this build
@property(nonatomic, copy) NSString *releaseNotes;

// The URL for the build
@property(nonatomic, strong) NSURL *downloadURL;

/** :nodoc: */
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithDictionary:(NSDictionary *)dict;

@end

NS_ASSUME_NONNULL_END
