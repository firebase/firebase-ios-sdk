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

@class RCNConfigFetch;
@class RCNConfigSettings;

@interface RCNRealtimeConfigHttpClient : UIViewController <NSURLSessionDataDelegate>

@property(weak, nonatomic) IBOutlet UILabel *outputLabel;
@property(strong, atomic) id <EventListener> eventListener;

- (instancetype) initWithClass:(RCNConfigFetch *) configFetch
                      settings: (RCNConfigSettings *)settings
                      namespace: (NSString *)namespace
                      options: (FIROptions *)options
                      queue: (dispatch_queue_t)queue;

- (void)startRealtimeConnection;
- (void)pauseRealtimeConnection;
- (ListenerRegistration *)setRealtimeEventListener:(id)eventListener;
- (void)removeRealtimeEventListener;

@end

#endif /* RealtimeConfigHttpClient_h */
