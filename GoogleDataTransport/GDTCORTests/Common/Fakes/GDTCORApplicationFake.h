//
//  GDTCORApplicationFake.h
//  Pods
//
//  Created by Maksym Malyhin on 2020-09-14.
//

#import <Foundation/Foundation.h>

#import "GoogleDataTransport/GDTCORLibrary/Public/GoogleDataTransport/GDTCORPlatform.h"

NS_ASSUME_NONNULL_BEGIN

typedef GDTCORBackgroundIdentifier (^GDTCORFakeBeginBackgroundTaskHandler)(
    NSString *name, dispatch_block_t handler);
typedef void (^GDTCORFakeEndBackgroundTaskHandler)(GDTCORBackgroundIdentifier);

@interface GDTCORApplicationFake : NSObject <GDTCORApplicationProtocol>

@property(nonatomic, copy, nullable) GDTCORFakeBeginBackgroundTaskHandler beginTaskHandler;
@property(nonatomic, copy, nullable) GDTCORFakeEndBackgroundTaskHandler endTaskHandler;

@end

NS_ASSUME_NONNULL_END
