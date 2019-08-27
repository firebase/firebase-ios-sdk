#import <Foundation/Foundation.h>

#import <FirebaseCore/FIROptionsInternal.h>

#import "SEGSegmentationConstants.h"

///
NS_ASSUME_NONNULL_BEGIN

@interface SEGNetworkManager : NSObject

- (instancetype)initWithFIROptions:(FIROptions *)options;

- (void)makeAssociationRequestToBackendWithData:
            (nonnull NSDictionary<NSString *, id> *)associationData
                                          token:(nonnull NSString *)token
                                     completion:(SEGRequestCompletion)completionHandler;

@end

NS_ASSUME_NONNULL_END
