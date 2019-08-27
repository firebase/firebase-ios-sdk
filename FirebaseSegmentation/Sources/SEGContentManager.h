#import <Foundation/Foundation.h>

#import "SEGSegmentationConstants.h"

NS_ASSUME_NONNULL_BEGIN

@class FIROptions;

@interface SEGContentManager : NSObject

/// Shared Singleton Instance
+ (instancetype)sharedInstanceWithFIROptions:(FIROptions*)options;

- (void)associateCustomInstallationIdentiferNamed:(nonnull NSString*)customInstallationID
                                      firebaseApp:(nonnull NSString*)firebaseApp
                                       completion:(SEGRequestCompletion)completionHandler;

@end

NS_ASSUME_NONNULL_END
