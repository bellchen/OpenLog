//
//  OpenLogModel.m
//  OpenLog
//
//  Created by bellchen on 2017/3/8.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLogModel.h"
#import "OpenLogJsonKit.h"
#import "OpenLogHelper.h"
#import "OpenLog.h"
#import "OpenLogReachability.h"
#import "OpenLogStorage.h"
@implementation OpenLogPing
-(NSString*) toJsonString{
    NSMutableDictionary* data = [[NSMutableDictionary alloc] init];
    data[@"domain"] = self.domain?:@"";
    data[@"port"] = @(self.port);
    data[@"ip"] = self.ip?:@"";
    data[@"success"] = @(self.success);
    data[@"timestamp"] = @(self.timestamp);
    data[@"duration"] = @(self.duration);
    NSString* str = [data jsonString];
    
    return str;
}

- (NSString*)description{
    return [self toJsonString];
}
@end

@implementation OpenLogUser

@end

@implementation OpenLogDevice

@end
@implementation OpenLogModel
@dynamic type;
- (instancetype)init{
    self = [super init];
    if (self) {
        self.timestamp = [[NSDate date] timeIntervalSince1970];
    }
    return self;
}
- (OpenLogModelType)type{
    return OpenLogModelTypeUnknown;
}
- (void)encode:(NSMutableDictionary *)data{
    //nothing to do
}
- (NSString*)toJsonString{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    if ([OpenLogHelper shareInstance].globalInfo) {
        [data addEntriesFromDictionary:[OpenLogHelper shareInstance].globalInfo];
    }
    NSString *appKey = [OpenLogHelper shareInstance].appKey;
    if (self.appKey) {
        appKey = self.appKey;
    }
    if (appKey) {
        data[@"ky"] = appKey;
    }
    data[@"ts"] = @(self.timestamp);
    data[@"sid"] = @(self.sessionID);
    static NSInteger kSeq = 1;
    data[@"idx"] = @(kSeq);
    kSeq++;
    
    OpenLogDevice *device = [OpenLogHelper shareInstance].device;
    data[@"os"] = @(0);//0表示iOS
    data[@"sv"] = device.sdkVersion;
    data[@"av"] = device.appVersion;
    
    data[@"mc"] = [OpenLogHelper macAddress];
    data[@"ifa"] = device.ifa;
    data[@"ifv"] = device.ifv;
    data[@"ui"] = device.deviceid;

    data[@"ch"] = [OpenLogConfigure shareInstance].channel;
    data[@"ut"] = @([OpenLogHelper shareInstance].user.userType);
    data[@"lt"] = @(self.type);
    
    [self encode:data];
    NSString *jsonString = [data jsonString];
    return jsonString;
}
@end

@implementation OpenLogPageViewModel

- (OpenLogModelType)type{
    return OpenLogModelTypePageView;
}

- (void)encode:(NSMutableDictionary *)data{
    data[@"pn"] = self.pageName;
    data[@"du"] = @(self.duration);
    if ([self.pageName isEqualToString:self.refer]) {
        self.refer = @"-";
    }
    if (self.refer) {
        data[@"rf"] = self.refer;
    }
}
@end

@implementation OpenLogSessionModel

- (OpenLogModelType)type{
    return OpenLogModelTypeSession;
}

- (void)encode:(NSMutableDictionary *)data{
    OpenLogDevice *device = [OpenLogHelper shareInstance].device;
    OpenLogUser *user = [OpenLogHelper shareInstance].user;
    NSMutableDictionary *env = [[NSMutableDictionary alloc] init];
    
    env[@"pl"] = device.platform;
    env[@"tz"] = device.timezone;
    env[@"lg"] = device.language;
    env[@"sr"] = device.resolution;
    env[@"nop"] = device.mccmnc;
    env[@"dn"] = device.deviceName;
    env[@"mn"] = device.modelName;
    env[@"jb"] = @(device.jailbroken);
    env[@"nw"] = [OpenLogHelper networkStatus];
    data[@"env"] = env;
    data[@"ut"] = @(user.userType);
    
    @autoreleasepool {
        NSMutableDictionary* cfg = [[NSMutableDictionary alloc]init];
        NSMutableDictionary* sdk = [[NSMutableDictionary alloc]init];
        NSMutableDictionary* app = [[NSMutableDictionary alloc]init];
        [sdk setObject:@([OpenLogConfigure shareInstance].reportStrategy) forKey:@"rs"];
        [[[OpenLogHelper shareInstance] onlineConfigureForType:OpenLogOnlineConfigTypeSDK] encode:sdk];
        [[[OpenLogHelper shareInstance] onlineConfigureForType:OpenLogOnlineConfigTypeApp] encode:app];
        [cfg setValue:sdk forKey:@"sdk"];
        [cfg setValue:app forKey:@"app"];
        [data setValue:cfg forKey:@"cfg"];
    }
}

@end

@implementation OpenLogErrorModel

- (OpenLogModelType)type{
    return OpenLogModelTypeError;
}

- (void)encode:(NSMutableDictionary *)data{
    NSArray<NSString*> *traces = [self.error componentsSeparatedByString:@"\n"];
    NSUInteger minLength = traces.count <= 100? traces.count : 100;
    data[@"er"] = [[traces subarrayWithRange:NSMakeRange(0, minLength)] componentsJoinedByString:@"\n"];
    data[@"et"] = @(self.errorType);
}

@end

@implementation OpenLogCustomModel

- (OpenLogModelType)type{
    return OpenLogModelTypeCustom;
}

- (void)encode:(NSMutableDictionary *)data{
    data[@"ln"] = self.logName;
    data[@"args"] = self.args;
    data[@"kvs"] = self.kvs;
    data[@"du"] = @(self.duration);
}

@end

@implementation OpenLogAdditionModel

- (OpenLogModelType)type{
    return OpenLogModelTypeAddition;
}

- (void)encode:(NSMutableDictionary *)data{
    [data addEntriesFromDictionary:self.info];
}

@end

@implementation OpenLogMonitorModel

- (OpenLogModelType)type{
    return OpenLogModelTypeMonitor;
}

- (void)encode:(NSMutableDictionary *)data{
    data[@"if"] = self.monitor.interface;
    data[@"rq"] = @(self.monitor.requestSize);
    data[@"rp"] = @(self.monitor.responseSize);
    data[@"du"] = @(self.monitor.duration);
    data[@"code"] = @(self.monitor.code);
    if (self.monitor.samplingRate == 0) {
        self.monitor.samplingRate = 1;
    }
    data[@"rate"] = @(self.monitor.samplingRate);
    data[@"rt"] = @(self.monitor.resultType);
    
    OpenLogDevice *device = [OpenLogHelper shareInstance].device;
    data[@"nop"] = device.mccmnc;
    data[@"nw"] = [OpenLogHelper networkStatus];
}
@end

@implementation OpenLogPingModel

- (OpenLogModelType)type{
    return OpenLogModelTypePing;
}

- (void)encode:(NSMutableDictionary *)data{
    data[@"ping"] = self.ping;
    data[@"sim"] = self.sim;
    data[@"nw"] = self.network;
}

@end
