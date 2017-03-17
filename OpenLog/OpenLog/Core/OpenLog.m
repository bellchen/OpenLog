//
//  OpenLog.m
//  OpenLog
//
//  Created by bellchen on 2017/3/7.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLog.h"
#import "OpenLogHelper.h"
#import "OpenLogStorage.h"
#import "OpenLogReporter.h"
#import "OpenLogModel.h"
#import "OpenLogReachability.h"
#import <UIKit/UIKit.h>
NSString * const OpenLog_Version = @"1.0.0";
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
    self.concurrentDurableLogMax = 1024;
    self.logLengthMax = 4096;
    self.smartyEnable = YES;
    self.wifiOnly = NO;
    self.shortAppVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
    if(self.shortAppVersion.length<=0){
        self.shortAppVersion = @"unknown";
    }
    self.channel = @"appstore";
    return self;
}
- (void)setGlobalValue:(NSObject *)value forKey:(NSString *)key{
    if (key && [key isKindOfClass:[NSString class]]) {
        [OpenLogHelper shareInstance].globalInfo[key] = value;
    }
}
- (void)cleanAllGlobal{
    [OpenLogHelper shareInstance].globalInfo = [NSMutableDictionary new];
}
- (NSString*)onlineConfigForKey:(nonnull NSString*)key default:(nonnull NSString*)value;{
    return [[OpenLogHelper shareInstance] appOnlineConfigForKey:key]?:value;
}
- (BOOL)openLogEnable{
    return _openLogEnable && [[OpenLogHelper shareInstance] checkOpenLogEnable];
}
@end
static NSString* kOpenLogLastSendTimestamp = @"OpenLogLastSendTimestamp";
@interface OpenLog ()
@property (strong, nonatomic) dispatch_queue_t taskQueue;
@property (strong, nonatomic) NSMutableDictionary *durablePageDictionary;
@property (strong, nonatomic) NSMutableDictionary *durableLogDictionary;
@property (strong, nonatomic) NSMutableArray<OpenLogModel*> *cachedLogs;
@property (assign, nonatomic) NSInteger lastActiveTimestamp;

@property (assign, nonatomic) NSUInteger sessionID;
@property (assign, nonatomic) NSInteger nextDayTimestamp;
@property (assign, nonatomic) NSInteger sessionLogCount;

@property (strong, nonatomic) NSString *currentPage;
@property (strong, nonatomic) NSString *lastPage;
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
    [[OpenLogHelper shareInstance] device];
    [[OpenLogHelper shareInstance] user];
    [[OpenLogStorage shareInstance] start];
    if ([OpenLogConfigure shareInstance].reportStrategy == OpenLogReportStrategyLaunch) {
        [[OpenLogStorage shareInstance] sendCachedLogs:-1];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onApplicationWillResignActiveNotification:)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onApplicationDidEnterBackgroundNotification:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onApplicationDidBecomeActiveNotification:)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onApplicationWillEnterForegroundNotification:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onApplicationWillTerminateNotification:)
                                                 name:UIApplicationWillTerminateNotification
                                               object:nil];
    
    return self;
}
#pragma mark - 对外接口
- (void)startWithAppKey:(NSString *)appKey{
    if(![[OpenLogConfigure shareInstance] openLogEnable]){
        return;
    }
    if (!appKey ||
        appKey.length == 0) {
        return;
    }
    [OpenLogHelper shareInstance].appKey = appKey;
    [self activeSessionID:YES];
}

- (void)startNewSession;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    [self activeSessionID:YES];
}
- (void)endCurrentSession;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    self.lastActiveTimestamp = 0;
}
- (void)reportLogs:(NSInteger)maxLogCount;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    [[OpenLogStorage shareInstance] sendCachedLogs:maxLogCount];
}
- (void)onPageBegin:(NSString*)pageName;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    if (!pageName || ![pageName isKindOfClass:[NSString class]] || pageName.length == 0) {
        NSLog(@"[Error]pageName cannot be nil/empty");
    }
    if ([OpenLogConfigure shareInstance].debug) {
        NSLog(@"onPageBegin:%@",pageName);
    }
    @synchronized (self.durablePageDictionary) {
        NSNumber * timestamp = self.durablePageDictionary[pageName];
        if (!timestamp) {
            NSLog(@"[Error]duplicate page :%@",pageName);
            return;
        }
        if (self.durablePageDictionary.count >= [OpenLogConfigure shareInstance].concurrentDurableLogMax) {
            return;
        }
        NSUInteger now = [[NSDate date] timeIntervalSince1970];
        self.durablePageDictionary[pageName] = @(now);
        self.currentPage = pageName;
    }
    [self activeSessionID:NO];
}
- (void)onPageEnd:(NSString*)pageName;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    if (!pageName || ![pageName isKindOfClass:[NSString class]] || pageName.length == 0) {
        NSLog(@"[Error]pageName cannot be nil/empty");
        return;
    }
    OpenLogPageViewModel *pageLog = nil;
    @synchronized (self.durablePageDictionary) {
        NSNumber *timestamp = self.durablePageDictionary[pageName];
        if (!timestamp) {
            NSLog(@"[Error] should begin page:%@ first",pageName);
            return;
        }
        NSInteger now = [[NSDate date] timeIntervalSince1970];
        NSInteger duration = now - [timestamp integerValue];
        if (duration <= 0) {
            duration = 1;
        }
        pageLog = [[OpenLogPageViewModel alloc] init];
        pageLog.pageName = pageName;
        pageLog.refer = self.lastPage;
        pageLog.sessionID = [self activeSessionID:NO];
        pageLog.duration = duration;
        [self.durablePageDictionary removeObjectForKey:pageName];
        self.lastPage = pageName;
        self.currentPage = nil;
    }
    [self reportLog:pageLog];
}
- (void)logPage:(NSString*)pageName duration:(NSInteger)duration;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    if (!pageName || ![pageName isKindOfClass:[NSString class]] || pageName.length == 0) {
        NSLog(@"[Error]pageName cannot be nil/empty");
        return;
    }
    OpenLogPageViewModel *pageLog = nil;
    if (duration <= 0) {
        duration = 1;
    }
    pageLog = [[OpenLogPageViewModel alloc] init];
    pageLog.pageName = pageName;
    pageLog.refer = self.lastPage;
    pageLog.sessionID = [self activeSessionID:NO];
    pageLog.duration = duration;
    self.lastPage = pageName;
    [self reportLog:pageLog];
}

- (void)onError:(NSString*)error;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    if (!error || ![error isKindOfClass:[NSString class]] || error.length == 0) {
        return;
    }
    OpenLogErrorModel *errorLog = [[OpenLogErrorModel alloc] init];
    errorLog.sessionID = [self activeSessionID:NO];
    errorLog.error = error;
    errorLog.errorType = OpenLogErrorModelTypeCaughtException;
    [self reportLog:errorLog];
}
- (void)onException:(NSException*)exception;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    if (!exception || ![exception isKindOfClass:[NSException class]]) {
        return ;
    }
    NSString *trackString = [[NSString alloc] initWithFormat:@"%@\n%@",exception.name,exception.callStackSymbols];
    OpenLogErrorModel *errorLog = [[OpenLogErrorModel alloc] init];
    errorLog.sessionID = [self activeSessionID:NO];
    errorLog.error = trackString;
    errorLog.errorType = OpenLogErrorModelTypeCaughtException;
    [self reportLog:errorLog];
}

- (void)onLog:(NSString*)logId args:(NSArray *)array;{
    
}
- (void)onLogBegin:(NSString *)logId args:(NSArray *)array;{
    
}
- (void)onLogEnd:(NSString *)logId args:(NSArray *)array;{
    
}
- (void)onLog:(NSString *)logId args:(NSArray *)array duration:(NSInteger)duration;{
    
}

- (void)onLog:(NSString *)logId kvs:(NSDictionary *)kvs;{
    
}
- (void)onLogBegin:(NSString *)logId kvs:(NSDictionary *)kvs;{
    
}
- (void)onLogEnd:(NSString *)logId kvs:(NSDictionary *)kvs;{
    
}
- (void)onLog:(NSString *)logId kvs:(NSDictionary *)kvs duration:(NSInteger)duration;{
    
}

- (void)onAddition:(NSDictionary*)additionInfo;{
    
}

- (void)onMonitor:(OpenLogInterfaceMonitor*)monitor;{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    if (!monitor || ![monitor isKindOfClass:[OpenLogInterfaceMonitor class]]) {
        return ;
    }
    OpenLogMonitorModel *monitorModel = [[OpenLogMonitorModel alloc] init];
    monitorModel.monitor = monitor;
    monitorModel.sessionID = [self activeSessionID:NO];
    [self reportLog:monitorModel];
}
#pragma mark - notification
- (void)onApplicationWillResignActiveNotification:(NSNotification*)notification{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    [self activeSessionID:NO];
    if (self.currentPage) {
        [self onPageEnd:self.currentPage];
    }
}
- (void)onApplicationDidEnterBackgroundNotification:(NSNotification*)notification{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    [self activeSessionID:NO];
}
- (void)onApplicationDidBecomeActiveNotification:(NSNotification*)notification{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    [self activeSessionID:NO];
    if (self.currentPage) {
        [self onPageBegin:self.currentPage];
    }
}
- (void)onApplicationWillEnterForegroundNotification:(NSNotification*)notification{
    if (![OpenLogConfigure shareInstance].openLogEnable) {
        return;
    }
    [self activeSessionID:NO];
}
- (void)onApplicationWillTerminateNotification:(NSNotification*)notification{
    [[OpenLogStorage shareInstance] stop];
}
#pragma mark - other
- (void)reportOneLog:(OpenLogModel*)log{
    if (!log) {
        return;
    }
    if ([OpenLogConfigure shareInstance].sessionLogMax > 0 &&
        [OpenLogConfigure shareInstance].sessionLogMax <= self.sessionLogCount) {
        if ([OpenLogConfigure shareInstance].debug) {
            NSLog(@"[Warn]session:%@ has too many log",self.sessionID);
        }
        return;
    }
    self.sessionLogCount ++;
    dispatch_async(self.taskQueue, ^{
        if (![OpenLogConfigure shareInstance].openLogEnable) {
            return ;
        }
        if ([OpenLogConfigure shareInstance].debug) {
            NSLog(@"[Info]handle log :%@",[log toJsonString]);
        }
        OpenLogReportStrategy strategy = [OpenLogConfigure shareInstance].reportStrategy;
        if (log.realTime) {
            strategy = OpenLogReportStrategyRealTime;
        }
        BOOL viaWifi = NO;
        @autoreleasepool {
            OpenLogReachability* reach = [OpenLogReachability reachabilityForInternetConnection];
            viaWifi = [reach isReachableViaWiFi];
            if((![reach isReachable]) ||
               (!viaWifi && [OpenLogConfigure shareInstance].wifiOnly)){
                [[OpenLogStorage shareInstance] storeLog:log complete:nil];
                return;
            }
        }
        void (^sendLog)(OpenLogModel*) = ^(OpenLogModel* willSendLog){
            if ([OpenLogStorage shareInstance].storedLogCount > 0) {
                [[OpenLogStorage shareInstance] storeLog:willSendLog complete:^{
                    [[OpenLogStorage shareInstance] sendCachedLogs:-1];
                }];
            }else{
                [[OpenLogReporter shareInstance] reportLog:willSendLog complete:^(BOOL success) {
                    if (success) {
                        [[OpenLogStorage shareInstance] sendCachedLogs:-1];
                    }else{
                        [[OpenLogStorage shareInstance] storeLog:willSendLog complete:nil];
                    }
                }];
            }
        };
        if ([OpenLogConfigure shareInstance].smartyEnable && viaWifi) {
            strategy = OpenLogReportStrategyRealTime;
        }
        switch (strategy) {
            case OpenLogReportStrategyManual:
            case OpenLogReportStrategyLaunch:{
                [[OpenLogStorage shareInstance] storeLog:log complete:nil];
                break;
            }
            case OpenLogReportStrategyBatch:{
                [[OpenLogStorage shareInstance] storeLog:log complete:^{
                    if ([OpenLogStorage shareInstance].storedLogCount >= [OpenLogConfigure shareInstance].batchLength) {
                        [[OpenLogStorage shareInstance] sendCachedLogs:[OpenLogConfigure shareInstance].batchLength];
                    }
                }];
                break;
            }
            case OpenLogReportStrategyPeriod:{
                [[OpenLogStorage shareInstance] storeLog:log complete:nil];
                NSInteger now = [[NSDate date] timeIntervalSince1970];
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                NSInteger lastSendTimestamp = [userDefaults integerForKey:kOpenLogLastSendTimestamp];
                if(lastSendTimestamp == 0){
                    [userDefaults setInteger:now forKey:kOpenLogLastSendTimestamp];
                    [userDefaults synchronize];
                }else{
                    if(now - lastSendTimestamp >= ([OpenLogConfigure shareInstance].periodInterval * 60)){
                        [[OpenLogStorage shareInstance] sendCachedLogs:-1];
                        [userDefaults setInteger:now forKey:kOpenLogLastSendTimestamp];
                        [userDefaults synchronize];
                    }
                }
                break;
            }
            case OpenLogReportStrategyRealTime:{
                sendLog(log);
                break;
            }
        }
    });
}
- (void)reportLog:(OpenLogModel*)log{
    NSMutableArray<OpenLogModel*> *cached = self.cachedLogs;
    @synchronized (cached) {
        if (cached.count > 0) {
            [cached enumerateObjectsUsingBlock:^(OpenLogModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([obj isKindOfClass:[OpenLogModel class]]) {
                    [self reportOneLog:obj];
                }
            }];
            [cached removeAllObjects];
        }
    }
    [self reportOneLog:log];
}
- (dispatch_queue_t)taskQueue{
    if (!_taskQueue) {
        _taskQueue = dispatch_queue_create("OpenLogQueue", NULL);
    }
    return _taskQueue;
}

- (NSInteger)activeSessionID:(BOOL)forceNewOne{
    return [self activeSessionID:forceNewOne realTime:NO];
}
- (NSInteger)activeSessionID:(BOOL)forceNewOne realTime:(BOOL)isRealTime{
    void (^reportSessionLog)() = ^(){
        if (self.sessionID == 0) {
            return ;
        }
        OpenLogSessionModel *sessionLog = [[OpenLogSessionModel alloc] init];
        sessionLog.sessionID = self.sessionID;
        sessionLog.appKey = [OpenLogHelper shareInstance].appKey;
        sessionLog.realTime = isRealTime;
        [self reportLog:sessionLog];
    };
    NSInteger now = [[NSDate date] timeIntervalSince1970];
    if (forceNewOne ||
        (now - self.lastActiveTimestamp >= [OpenLogConfigure shareInstance].sessionTime) ||
        (now >= self.nextDayTimestamp)) {
        self.sessionID = [self generateSessionID];
        reportSessionLog();
    }
    self.lastActiveTimestamp = now;
    if (self.sessionID == 0) {
        self.sessionID = [self generateSessionID];
        reportSessionLog();
    }
    return 0;
}
- (NSInteger)generateSessionID{
    self.sessionLogCount = 0;
    time_t now = [[NSDate date] timeIntervalSince1970];
    srandom((unsigned)now);
    struct tm td;
    localtime_r(&now, &td);
    self.nextDayTimestamp = now  - (td.tm_hour*3600 +  td.tm_min * 60 + td.tm_sec) + 24*3600;
    return (NSInteger)random();
}

#pragma mark - lazy init
- (NSMutableDictionary*)durablePageDictionary{
    if (!_durablePageDictionary) {
        _durablePageDictionary = [[NSMutableDictionary alloc] init];
    }
    return _durablePageDictionary;
}
- (NSMutableDictionary*)durableLogDictionary{
    if (!_durableLogDictionary) {
        _durableLogDictionary = [[NSMutableDictionary alloc] init];
    }
    return _durableLogDictionary;
}
- (NSMutableArray*)cachedLogs{
    if (!_cachedLogs) {
        _cachedLogs = [[NSMutableArray alloc] init];
    }
    return _cachedLogs;
}
@end
