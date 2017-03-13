//
//  OpenLog.m
//  OpenLog
//
//  Created by bellchen on 2017/3/7.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLog.h"
#import "OpenLogHelper.h"
@implementation OpenLogInterfaceMonitor

@end

static OpenLogConfigure *openLogConfigureInstance = nil;
@implementation OpenLogConfigure
+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        openLogConfigureInstance = [[self alloc] init];
    });
    return openLogConfigureInstance;
}
+ (instancetype)shareInstance{
    return [[self alloc] init];
}
- (instancetype)copyWithZone:(NSZone *)zone{
    return openLogConfigureInstance;
}
- (instancetype)mutableCopyWithZone:(NSZone *)zone{
    return openLogConfigureInstance;
}
- (instancetype)init{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.debug = NO;
    self.openLogEnable = YES;
    self.sessionTime = 600;
    self.reportStrategy = OpenLogReportStrategyLaunch;
    self.storeLogMax = 1024;
    self.reportLogLength = 30;
    self.reportRetryMax = 3;
    self.batchLength = 30;
    self.periodInterval = 3;
    self.concurrentDurableEventMax = 1024;
    self.logLengthMax = 4096;
    self.smartyEnable = YES;
    self.shortAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if(self.shortAppVersion.length<=0){
        self.shortAppVersion = @"unknown";
    }
    self.channel = @"appstore";
    return self;
}
@end
@interface OpenLog ()
@property (strong, nonatomic) dispatch_queue_t reportQueue;
@end
@implementation OpenLog
static OpenLog *openLogInstance = nil;
+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        openLogInstance = [[self alloc] init];
    });
    return openLogInstance;
}
+ (instancetype)shareInstance{
    return [[self alloc] init];
}
- (instancetype)copyWithZone:(NSZone *)zone{
    return openLogInstance;
}
- (instancetype)mutableCopyWithZone:(NSZone *)zone{
    return openLogInstance;
}
- (instancetype)init{
    self = [super init];
    if (!self) {
        return nil;
    }
    
    return self;
}

- (dispatch_queue_t)reportQueue{
    if (!_reportQueue) {
        _reportQueue = dispatch_queue_create("OpenLogQueue", NULL);
    }
    return _reportQueue;
}
- (void)startWithAppKey:(NSString *)appKey{
    if(![[OpenLogConfigure shareInstance] openLogEnable]){
        return;
    }
    if (!appKey ||
        appKey.length == 0) {
        return;
    }
    [OpenLogHelper shareInstance].appKey = appKey;
    [self createSessionID:YES withAppKey:nil];
}
- (NSInteger)createSessionID:(BOOL)checkSession withAppKey:(NSString*)appKey{
    return 0;
}
- (NSInteger)createSessionID:(BOOL)checkSession withAppKey:(NSString*)appKey realTime:(BOOL)isRealTime{
    return 0;
}
@end
