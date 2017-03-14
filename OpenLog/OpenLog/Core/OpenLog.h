//
//  OpenLog.h
//  OpenLog
//
//  Created by bellchen on 2017/3/7.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>
extern NSString * const OpenLog_Version;
typedef NS_ENUM(NSInteger, OpenLogReportStrategy) {
    OpenLogReportStrategyLaunch = 1,//启动时上报
    OpenLogReportStrategyBatch,//批量上报
    OpenLogReportStrategyPeriod,//定时上报
    OpenLogReportStrategyManual,
    OpenLogReportStrategyRealTime,
};
typedef NS_ENUM(NSInteger, OpenLogInterfaceResultType) {
    OpenLogInterfaceResultTypeSuccess = 0,//标记接口请求成功
    OpenLogInterfaceResultTypeFailure,//标记接口请求失败
    OpenLogInterfaceResultTypeLogicFailure,//标记接口请求成功但返回内容逻辑失败
};
@interface OpenLogInterfaceMonitor : NSObject
@property (copy, nonatomic) NSString *interface;//监控接口名
@property (assign, nonatomic) NSInteger requestSize;//上行数据量，单位字节
@property (assign, nonatomic) NSInteger responseSize;//下行数据量，单位字节
@property (assign, nonatomic) NSInteger duration;//耗时，单位毫秒
@property (assign, nonatomic) NSInteger code;//应答码
@property (assign, nonatomic) NSInteger samplingRate;//接口采样率，默认0表示无采样，和1一样
@property (assign, nonatomic) OpenLogInterfaceResultType resultType;//标记返回类型
@end
@interface OpenLogConfigure : NSObject
@property (assign, nonatomic) BOOL debug;//debug开关，默认NO
@property (assign, nonatomic) BOOL openLogEnable;//是否启用openLog，默认YES
@property (assign, nonatomic) NSInteger sessionTime;//会话时长，单位秒，默认10分钟(600)
@property (assign, nonatomic) OpenLogReportStrategy reportStrategy;//上报策略，默认为Launch
@property (assign, nonatomic) NSInteger storeLogMax;//本地存储的最大日志数，超过将删除最旧数据，默认1024
@property (assign, nonatomic) NSInteger reportLogLength;//单次上报日志数，默认30
@property (assign, nonatomic) NSInteger reportRetryMax;//每条日志上报失败重试次数，默认3
@property (assign, nonatomic) NSInteger batchLength;//上报策略为batch时，批量上报阈值，默认30
@property (assign, nonatomic) NSInteger periodInterval;//上报策略为PERIOD时发送间隔，单位分钟，默认3分钟
@property (assign, nonatomic) NSInteger concurrentDurableEventMax;//时长时间最大并发数，默认1024
@property (assign, nonatomic) NSInteger logLengthMax;//单条日志最大长度，默认4096
@property (assign, nonatomic) BOOL smartyEnable;//智能上报开关，wifi下实时上报，非wifi下遵循上报策略，默认YES
@property (copy, nonatomic) NSString *shortAppVersion;//默认统计CFBundleShortVersionString中的版本号（即与AppStore上一致的版本号）
@property (copy, nonatomic) NSString *channel;//渠道号，默认appstore
@property (copy, nonatomic) NSString *reportUrl;//post 数据提交的url
@property (copy, nonatomic) void(^reportBlock)(NSArray<NSString*>*);
+ (instancetype)shareInstance;
/**
 *  @method setGlobalValue:forKey:
 *  添加全局的字段，每条日志都带上
 *  @param  value       NSObject类型，或者是NSString 或者NSNumber类型，当值为nil时为删除该key
 *  @param  key         自定义字段的key，有相同的key，则会覆盖
 */
- (void)setGlobalValue:(nullable NSObject*)value forKey:(nonnull NSString*)key;
/**
 *  @method cleanAllGlobal
 *  删除全局自定义字段
 */
- (void)cleanAllGlobal;
@end
@interface OpenLog : NSObject
- (void)startWithAppKey:(nonnull NSString*)appKey;
- (NSString*)onlineConfigForKey:(nonnull NSString*)key default:(nonnull NSString*)value;
@end
