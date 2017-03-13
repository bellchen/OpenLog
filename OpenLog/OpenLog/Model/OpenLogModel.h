//
//  OpenLogModel.h
//  OpenLog
//
//  Created by bellchen on 2017/3/8.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, OpenLogUserType) {
    OpenLogUserTypeNew = 0,
    OpenLogUserTypeOld,
    OpenLogUserTypeUpgrade,
};
@interface OpenLogUser : NSObject
@property (copy, nonatomic) NSString *uid;
@property (assign, nonatomic) OpenLogUserType userType;
@property (copy, nonatomic) NSString *appVersion;
@property (assign, nonatomic) NSInteger tagTime;
@end

@interface OpenLogDevice : NSObject
@property (copy, nonatomic) NSString *platform;
@property (copy ,nonatomic) NSString *osVersion;
@property (copy, nonatomic) NSString *language;
@property (copy, nonatomic) NSString *deviceid;
@property (copy, nonatomic) NSString *mccmnc;
@property (copy, nonatomic) NSString *timezone;
@property (copy, nonatomic) NSString *appVersion;
@property (copy, nonatomic) NSString *sdkVersion;
@property (copy, nonatomic) NSString *deviceName;
@property (copy, nonatomic) NSString *modelName;
@property (copy, nonatomic) NSString *ifa;
@property (copy, nonatomic) NSString *ifv;
@property (assign, nonatomic) BOOL jailbroken;
@property (copy, nonatomic) NSString *wifi;
@end

@interface OpenLogPingModel : NSObject
@property (copy, nonatomic) NSString *domain;//ping 的域名
@property (assign, nonatomic) NSInteger port;//ping 的端口
@property (copy, nonatomic) NSString *ip;//ping 域名对应的IP
@property (assign, nonatomic) BOOL success;//是否成功
@property (assign, nonatomic) NSInteger timestamp;//ping的时间戳
@property (assign, nonatomic) NSInteger duration;//ping 耗时

- (NSString*)toJsonString;
@end

typedef NS_ENUM(NSInteger, OpenLogModelType) {
    OpenLogModelTypeUnknown = 0,
    OpenLogModelTypeSession,
    OpenLogModelTypePageView,
    OpenLogModelTypeError,
    OpenLogModelTypeCustom,
    OpenLogModelTypeAddition,
    OpenLogModelTypeMonitor,
    OpenLogModelTypePing,
};

@protocol OpenLogModelProtocol <NSObject>
@property (assign, nonatomic) OpenLogModelType type;
- (void)encode:(NSMutableDictionary*)data;
@end

@interface OpenLogModel : NSObject<OpenLogModelProtocol>
@property (assign, nonatomic) NSInteger sessionID;
@property (assign, nonatomic) NSInteger timestamp;
@property (copy, nonatomic) NSString *appKey;
@property (assign, nonatomic) BOOL realTime;
- (instancetype)init;
- (NSString*)toJsonString;
@end

@interface OpenLogModelSession : OpenLogModel

@end

@interface OpenLogModelPageView : OpenLogModel
@property (assign, nonatomic) NSInteger duration;
@property (copy, nonatomic) NSString *pageName;
@property (copy, nonatomic) NSString *refer;
@end

@interface OpenLogModelError : OpenLogModel
@property (copy, nonatomic) NSString *error;
@end

@interface OpenLogModelCustom : OpenLogModel
@property (copy, nonatomic) NSString *logName;
@property (strong, nonatomic) NSArray *args;
@property (strong, nonatomic) NSDictionary *attr;
@property (assign, nonatomic) NSInteger duration;
@end

@interface OpenLogModelAddition : OpenLogModel

@end

@interface OpenLogModelMonitor : OpenLogModel

@end

@interface OpenLogModelPing : OpenLogModel
@property (copy, nonatomic) NSString *ping;
@property (copy, nonatomic) NSString *sim;
@property (copy, nonatomic) NSString *network;
@end
