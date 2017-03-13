//
//  OpenLogReachability.m
//  OpenLog
//
//  Created by bellchen on 2017/3/8.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLogReachability.h"
#import <sys/socket.h>
#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>

NSString *const kOpenLogReachabilityChangedNotification = @"kOpenLogReachabilityChangedNotification";

@interface OpenLogReachability ()
@property (assign, nonatomic) SCNetworkReachabilityRef reachabilityRef;
@property (strong, nonatomic) dispatch_queue_t reachabilitySerialQueue;
@property (strong, nonatomic) OpenLogReachability *reachabilityObject;

- (void)reachabilityChanged:(SCNetworkReachabilityFlags)flags;
- (BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags;
@end
static NSString *reachabilityFlags(SCNetworkReachabilityFlags flags){
    return [NSString stringWithFormat:@"%c%c %c%c%c%c%c%c%c",
            (flags & kSCNetworkReachabilityFlagsIsWWAN)               ? 'W' : '-',
            (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
            (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
            (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
            (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
            (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
            (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-'];
}

//Start listening for reachability notifications on the current run loop
static void TMReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info){
    OpenLogReachability *reachability = ((__bridge OpenLogReachability*)info);
    @autoreleasepool{
        [reachability reachabilityChanged:flags];
    }
}

@implementation OpenLogReachability

+ (OpenLogReachability*)reachabilityWithHostname:(NSString*)hostname{
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithName(NULL, [hostname UTF8String]);
    if (ref){
        OpenLogReachability *reachability = [[self alloc] initWithReachabilityRef:ref];
        return reachability;
    }
    return nil;
}

+ (OpenLogReachability*)reachabilityWithAddress:(const struct sockaddr_in *)hostAddress{
    SCNetworkReachabilityRef ref = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr*)hostAddress);
    if (ref){
        OpenLogReachability *reachability = [[self alloc] initWithReachabilityRef:ref];
        return reachability;
    }
    return nil;
}

+ (OpenLogReachability*)reachabilityForInternetConnection{
    struct sockaddr_in zeroAddress;
    bzero(&zeroAddress, sizeof(zeroAddress));
    zeroAddress.sin_len = sizeof(zeroAddress);
    zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress:&zeroAddress];
}

+ (OpenLogReachability*)reachabilityForLocalWiFi{
    struct sockaddr_in localWifiAddress;
    bzero(&localWifiAddress, sizeof(localWifiAddress));
    localWifiAddress.sin_len            = sizeof(localWifiAddress);
    localWifiAddress.sin_family         = AF_INET;
    // IN_LINKLOCALNETNUM is defined in <netinet/in.h> as 169.254.0.0
    localWifiAddress.sin_addr.s_addr    = htonl(IN_LINKLOCALNETNUM);
    
    return [self reachabilityWithAddress:&localWifiAddress];
}


// initialization methods

- (OpenLogReachability*)initWithReachabilityRef:(SCNetworkReachabilityRef)ref{
    self = [super init];
    if (self){
        self.reachableOnWWAN = YES;
        self.reachabilityRef = ref;
    }
    
    return self;
}

-(void)dealloc{
    [self stopNotifier];
    
    if(self.reachabilityRef){
        CFRelease(self.reachabilityRef);
        self.reachabilityRef = nil;
    }
    
    self.reachableBlock = nil;
    self.unreachableBlock = nil;
}

#pragma mark - notifier methods

// Notifier
// NOTE: this uses GCD to trigger the blocks - they *WILL NOT* be called on THE MAIN THREAD
// - In other words DO NOT DO ANY UI UPDATES IN THE BLOCKS.
//   INSTEAD USE dispatch_async(dispatch_get_main_queue(), ^{UISTUFF}) (or dispatch_sync if you want)

- (BOOL)startNotifier{
    SCNetworkReachabilityContext context = { 0, NULL, NULL, NULL, NULL };
    
    // this should do a retain on ourself, so as long as we're in notifier mode we shouldn't disappear out from under ourselves
    // woah
    self.reachabilityObject = self;
    
    // first we need to create a serial queue
    // we allocate this once for the lifetime of the notifier
    self.reachabilitySerialQueue = dispatch_queue_create("openlog.reachability", NULL);
    if(!self.reachabilitySerialQueue){
        return NO;
    }
    
    context.info = (__bridge void *)self;
    
    if (!SCNetworkReachabilitySetCallback(self.reachabilityRef, TMReachabilityCallback, &context)){
        //clear out the dispatch queue
        if(self.reachabilitySerialQueue){
            self.reachabilitySerialQueue = nil;
        }
        
        self.reachabilityObject = nil;
        
        return NO;
    }
    
    // set it as our reachability queue which will retain the queue
    if(!SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, self.reachabilitySerialQueue)){
        
        //UH OH - FAILURE!
        
        // first stop any callbacks!
        SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
        
        // then clear out the dispatch queue
        if(self.reachabilitySerialQueue){
            self.reachabilitySerialQueue = nil;
        }
        
        self.reachabilityObject = nil;
        
        return NO;
    }
    
    return YES;
}

- (void)stopNotifier{
    // first stop any callbacks!
    SCNetworkReachabilitySetCallback(self.reachabilityRef, NULL, NULL);
    
    // unregister target from the GCD serial dispatch queue
    SCNetworkReachabilitySetDispatchQueue(self.reachabilityRef, NULL);
    
    if(self.reachabilitySerialQueue){
        self.reachabilitySerialQueue = nil;
    }
    
    self.reachabilityObject = nil;
}

#pragma mark - reachability tests

// this is for the case where you flick the airplane mode
// you end up getting something like this:
//Reachability: WR ct-----
//Reachability: -- -------
//Reachability: WR ct-----
//Reachability: -- -------
// we treat this as 4 UNREACHABLE triggers - really apple should do better than this

#define testcase (kSCNetworkReachabilityFlagsConnectionRequired | kSCNetworkReachabilityFlagsTransientConnection)

- (BOOL)isReachableWithFlags:(SCNetworkReachabilityFlags)flags{
    BOOL connectionUP = YES;
    
    if(!(flags & kSCNetworkReachabilityFlagsReachable)){
        connectionUP = NO;
    }
    if( (flags & testcase) == testcase ){
        connectionUP = NO;
    }
    if(flags & kSCNetworkReachabilityFlagsIsWWAN){
        // we're on 3G
        if(!self.reachableOnWWAN){
            // we dont want to connect when on 3G
            connectionUP = NO;
        }
    }
    
    return connectionUP;
}

- (BOOL)isReachable{
    SCNetworkReachabilityFlags flags;
    
    if(!SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
        return NO;
    
    return [self isReachableWithFlags:flags];
}

- (BOOL)isReachableViaWWAN{
    
    SCNetworkReachabilityFlags flags = 0;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)){
        // check we're REACHABLE
        if(flags & kSCNetworkReachabilityFlagsReachable){
            // now, check we're on WWAN
            if(flags & kSCNetworkReachabilityFlagsIsWWAN){
                return YES;
            }
        }
    }
    
    return NO;
}

- (BOOL)isReachableViaWiFi{
    SCNetworkReachabilityFlags flags = 0;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)){
        // check we're reachable
        if((flags & kSCNetworkReachabilityFlagsReachable)){
            // check we're NOT on WWAN
            if(flags & kSCNetworkReachabilityFlagsIsWWAN){
                return NO;
            }
            return YES;
        }
    }
    
    return NO;
}


// WWAN may be available, but not active until a connection has been established.
// WiFi may require a connection for VPN on Demand.
- (BOOL)isConnectionRequired{
    return [self connectionRequired];
}

- (BOOL)connectionRequired{
    SCNetworkReachabilityFlags flags;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)){
        return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
    }
    
    return NO;
}

// Dynamic, on demand connection?
- (BOOL)isConnectionOnDemand{
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags))
    {
        return ((flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
                (flags & (kSCNetworkReachabilityFlagsConnectionOnTraffic | kSCNetworkReachabilityFlagsConnectionOnDemand)));
    }
    
    return NO;
}

// Is user intervention required?
- (BOOL)isInterventionRequired{
    SCNetworkReachabilityFlags flags;
    
    if (SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)){
        return ((flags & kSCNetworkReachabilityFlagsConnectionRequired) &&
                (flags & kSCNetworkReachabilityFlagsInterventionRequired));
    }
    
    return NO;
}


#pragma mark - reachability status stuff

-(OpenLogNetworkStatus)currentReachabilityStatus{
    if([self isReachable]){
        if([self isReachableViaWiFi]){
            return OpenLogReachableViaWiFi;
        }
        return OpenLogReachableViaWWAN;
    }
    
    return OpenLogNotReachable;
}

-(SCNetworkReachabilityFlags)reachabilityFlags{
    SCNetworkReachabilityFlags flags = 0;
    
    if(SCNetworkReachabilityGetFlags(self.reachabilityRef, &flags)){
        return flags;
    }
    
    return 0;
}

-(NSString*)currentReachabilityString{
    OpenLogNetworkStatus temp = [self currentReachabilityStatus];
    
    if(temp == self.reachableOnWWAN){
        // updated for the fact we have CDMA phones now!
        return NSLocalizedString(@"Cellular", @"");
    }
    if (temp == OpenLogReachableViaWiFi){
        return NSLocalizedString(@"WiFi", @"");
    }
    
    return NSLocalizedString(@"No Connection", @"");
}

-(NSString*)currentReachabilityFlags{
    return reachabilityFlags([self reachabilityFlags]);
}

#pragma mark - callback function calls this method

-(void)reachabilityChanged:(SCNetworkReachabilityFlags)flags{
    if([self isReachableWithFlags:flags]){
        if(self.reachableBlock){
            self.reachableBlock(self);
        }
    }else{
        if(self.unreachableBlock){
            self.unreachableBlock(self);
        }
    }
    
    // this makes sure the change notification happens on the MAIN THREAD
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kOpenLogReachabilityChangedNotification
                                                            object:self];
    });
}
@end
