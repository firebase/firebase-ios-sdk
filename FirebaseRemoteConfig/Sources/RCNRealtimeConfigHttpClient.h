//
//  RealtimeConfigHttpClient.h
//  Pods
//
//  Created by Quan Pham on 2/8/22.
//

#ifndef RealtimeConfigHttpClient_h
#define RealtimeConfigHttpClient_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface RCNRealtimeConfigHttpClient : UIViewController <NSURLSessionDataDelegate>

@property(weak, nonatomic) IBOutlet UILabel *outputLabel;
@property(strong, atomic) id <RealTimeDelegateCallback> realTimeDelegate;

- (instancetype) initWithClass:(RCNConfigFetch *) configFetch;
- (void)setRealTimeDelegateCallback:(id)realTimeDelegate;
- (void)removeRealTimeDelegateCallback;
- (void)startStream;
- (void)pauseStream;

@end

#endif /* RealtimeConfigHttpClient_h */
