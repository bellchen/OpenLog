//
//  OpenLogReachability.h
//  OpenLog
//
//  Created by bellchen on 2017/3/8.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SystemConfiguration/SystemConfiguration.h>

extern NSString *const kOpenLogReachabilityChangedNotification;

typedef NS_ENUM(NSInteger, OpenLogNetworkStatus) {
    OpenLogNotReachable     = 0,
    OpenLogReachableViaWiFi = 2,
    OpenLogReachableViaWWAN = 1
};

@interface OpenLogReachability : NSObject
@property (copy, nonatomic) void(^reachableBlock)(OpenLogReachability *reachability);
@property (copy, nonatomic) void(^unreachableBlock)(OpenLogReachability *reachability);

@property (assign, nonatomic) BOOL reachableOnWWAN;

+ (OpenLogReachability*)reachabilityWithHostname:(NSString*)hostname;
+ (OpenLogReachability*)reachabilityForInternetConnection;
+ (OpenLogReachability*)reachabilityWithAddress:(const struct sockaddr_in*)hostAddress;
+ (OpenLogReachability*)reachabilityForLocalWiFi;

- (OpenLogReachability*)initWithReachabilityRef:(SCNetworkReachabilityRef)ref;

- (BOOL)startNotifier;
- (void)stopNotifier;

- (BOOL)isReachable;
- (BOOL)isReachableViaWWAN;
- (BOOL)isReachableViaWiFi;

// WWAN may be available, but not active until a connection has been established.
// WiFi may require a connection for VPN on Demand.
- (BOOL)isConnectionRequired; // Identical DDG variant.
- (BOOL)connectionRequired; // Apple's routine.
// Dynamic, on demand connection?
- (BOOL)isConnectionOnDemand;
// Is user intervention required?
- (BOOL)isInterventionRequired;

- (OpenLogNetworkStatus)currentReachabilityStatus;
- (SCNetworkReachabilityFlags)reachabilityFlags;
- (NSString*)currentReachabilityString;
- (NSString*)currentReachabilityFlags;

@end
