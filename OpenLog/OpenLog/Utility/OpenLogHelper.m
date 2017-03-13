//
//  OpenLogHelper.m
//  OpenLog
//
//  Created by bellchen on 2017/3/9.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLogHelper.h"
#import <net/if.h> // For IFF_LOOPBACK
#include <net/if_dl.h>
#import <sys/sysctl.h>

#import <zlib.h>


//#import <arpa/inet.h>
//#import <netdb.h>
//#include <setjmp.h>

//#import <SystemConfiguration/SystemConfiguration.h>
//#import <arpa/inet.h> // For AF_INET, etc.
//#import <ifaddrs.h> // For getifaddrs()

//#import <sys/utsname.h>
//#include <sys/ioctl.h>
//#include <sys/types.h>
//#include <sys/socket.h>
//#include <netinet/in.h>
//#include <netdb.h>
//#include <sys/sockio.h>

//#import <zlib.h>
//#import <SystemConfiguration/CaptiveNetwork.h>
//#import <CoreTelephony/CTTelephonyNetworkInfo.h>
//#import <CoreTelephony/CTCarrier.h>
//#import <CoreTelephony/CTCall.h>
//#import <CoreTelephony/CTCallCenter.h>
//#import <UIKit/UIKit.h>
#import "OpenLogStorage.h"
#import "OpenLog.h"
#import "OpenLogJsonKit.h"
#import "OpenLogStorage.h"
#import "OpenLogModel.h"
#import "OpenLogReporter.h"
#import "OpenLogReachability.h"
//#import "OpenLogUDID.h"
@interface OpenLogHelper()
@property (assign, nonatomic) BOOL openLogEnable;
@property (strong, nonatomic) OpenLogOnlineConfigure *sdkConfigure;
@property (strong, nonatomic) OpenLogOnlineConfigure *appConfigure;
@property (strong, nonatomic) NSMutableDictionary *appConfigureDictionary;
@end
@implementation OpenLogHelper
static OpenLogHelper *instance = nil;
+ (instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}
+ (instancetype)shareInstance{
    return [[self alloc] init];
}
- (instancetype)copyWithZone:(NSZone *)zone{
    return instance;
}
- (instancetype)mutableCopyWithZone:(NSZone *)zone{
    return instance;
}
- (instancetype)init{
    self = [super init];
    if (!self) {
        return nil;
    }
    self.openLogEnable = YES;
    [[OpenLogStorage shareInstance] loadConfigure:^(OpenLogOnlineConfigure *cfg) {
        [self loadConfigure:cfg];
    }];
    return self;
}
- (BOOL)checkOpenLogEnable;{
    return self.openLogEnable;
}
- (NSString*)appOnlineConfigForKey:(NSString*)key;{
    return self.appConfigureDictionary[key];
}
- (void)updateOnlineConfig:(NSDictionary*)onlineConfig;{
    if (!onlineConfig) {
        return;
    }
    NSDictionary* cfg = onlineConfig[@"cfg"];
    if(cfg && [cfg isKindOfClass:[NSDictionary class]]){
        NSDictionary* sdkCfg = cfg[@"sdk"];
        NSDictionary* appCfg = cfg[@"app"];
        if(sdkCfg && [sdkCfg isKindOfClass:[NSDictionary class]]){
            [self updateConfig:sdkCfg forType:OpenLogOnlineConfigTypeSDK];
        }
        if(appCfg && [appCfg isKindOfClass:[NSDictionary class]]){
            [self updateConfig:appCfg forType:OpenLogOnlineConfigTypeApp];
        }
    }
}
- (OpenLogOnlineConfigure*)onlineConfigureForType:(OpenLogOnlineConfigType)type;{
    if (type == OpenLogOnlineConfigTypeSDK) {
        return self.sdkConfigure;
    }
    if (type == OpenLogOnlineConfigTypeApp) {
        return self.appConfigure;
    }
    return nil;
}
- (void)updateConfig:(NSDictionary*)dic forType:(OpenLogOnlineConfigType)type {
    @autoreleasepool {
        OpenLogOnlineConfigure* configure = [[OpenLogOnlineConfigure alloc] init];
        if([configure decode:dic]){
            [configure setType:type];
            OpenLogOnlineConfigure* currentCfg = [self onlineConfigureForType:type];
            NSInteger currentVer = currentCfg.version;
            if(currentVer < configure.version){
                [self loadConfigure:configure];
                [[OpenLogStorage shareInstance] storeConfigure:configure];
            }
        }else{
            NSLog(@"[ERROR]Failed to decode config for %@", dic);
        }
    }
}
- (void)loadConfigure:(OpenLogOnlineConfigure*)configure{
    NSDictionary *configObj = [configure.content objectFromJson];
    if(![configObj isKindOfClass:[NSDictionary class]]){
        NSLog(@"Not NSDictionary for decoded response config object:%@", [configObj class]);
        return;
    }
    if (configure.type == OpenLogOnlineConfigTypeApp) {
        self.appConfigure = configure;
        self.appConfigureDictionary = configObj;
    }
    if (configure.type == OpenLogOnlineConfigTypeSDK) {
        self.sdkConfigure = configure;
        
        NSNumber* strategyNumber = configObj[@"__Strategy__"];
        if(strategyNumber && [strategyNumber isKindOfClass:[NSNumber class]]){
            NSInteger strategy = strategyNumber.integerValue;
            if (strategy >= OpenLogReportStrategyLaunch && strategy <= OpenLogReportStrategyRealTime) {
                [OpenLogConfigure shareInstance].reportStrategy = strategy;
            }
        }
        
        NSString* atLeastVersion = configObj[@"__AtLeast__"];
        if(atLeastVersion && [atLeastVersion isEqualToString:[NSString class]]){
            if([atLeastVersion compare:OpenLog_Version options:NSNumericSearch] != NSOrderedAscending){
                self.openLogEnable = NO;
            }
        }
        
        NSDictionary* disableDic = configObj[@"__Disable__"];
        if (disableDic && [disableDic isKindOfClass:[NSDictionary class]]) {
            OpenLogDevice *device = self.device;
            //禁用SDK版本
            NSArray<NSString*> *dSdkVersionArray = disableDic[@"sv"];
            if (device.sdkVersion && dSdkVersionArray && [dSdkVersionArray isKindOfClass:[NSArray class]]) {
                [dSdkVersionArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([obj isEqualToString:device.sdkVersion]) {
                        self.openLogEnable = NO;
                        *stop = YES;
                    }
                }];
            }
            //禁用设备型号
            NSArray<NSString*> *dDeviceModelArray = disableDic[@"dm"];
            if (device.modelName && dDeviceModelArray && [dDeviceModelArray isKindOfClass:[NSArray class]]) {
                [dDeviceModelArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([obj isEqualToString:device.modelName]) {
                        self.openLogEnable = NO;
                        *stop = YES;
                    }
                }];
            }
            //禁用App版本号
            NSArray<NSString*> *dAppVersionArray = disableDic[@"av"];
            if (device.appVersion && dAppVersionArray && [dAppVersionArray isKindOfClass:[NSArray class]]) {
                [dAppVersionArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    if ([obj isEqualToString:device.appVersion]) {
                        self.openLogEnable = NO;
                        *stop = YES;
                    }
                }];
            }
        }
        
        NSArray<NSString*>* pingArray = [configObj objectForKey:@"__Ping__"];
        if (pingArray && [pingArray isKindOfClass:[NSArray class]]) {
            dispatch_async(dispatch_queue_create("openlog.ping", NULL), ^{
                OpenLogReachability* reach = [OpenLogReachability reachabilityForInternetConnection];
                if(![reach isReachable]){
                    return;
                }
                OpenLogModelPing *pingModel = [[OpenLogReporter shareInstance] ping:pingArray];
                [[OpenLogStorage shareInstance] storeLog:pingModel complete:nil];
            });
        }
    }
}
+ (NSString*)macAddress;{
    int                 mgmtInfoBase[6];
    char                *msgBuffer = NULL;
    size_t              length;
    unsigned char       macAddress[6];
    struct if_msghdr    *interfaceMsgStruct;
    struct sockaddr_dl  *socketStruct;
    NSString            *errorFlag = NULL;
    
    // Setup the management Information Base (mib)
    mgmtInfoBase[0] = CTL_NET;        // Request network subsystem
    mgmtInfoBase[1] = AF_ROUTE;       // Routing table info
    mgmtInfoBase[2] = 0;
    mgmtInfoBase[3] = AF_LINK;        // Request link layer information
    mgmtInfoBase[4] = NET_RT_IFLIST;  // Request all configured interfaces
    
    // With all configured interfaces requested, get handle index
    if ((mgmtInfoBase[5] = if_nametoindex("en0")) == 0){
        errorFlag = @"if_nametoindex failure";
    }else{
        // Get the size of the data available (store in len)
        if (sysctl(mgmtInfoBase, 6, NULL, &length, NULL, 0) < 0){
            errorFlag = @"sysctl mgmtInfoBase failure";
        }else{
            // Alloc memory based on above call
            if ((msgBuffer = malloc(length)) == NULL){
                errorFlag = @"buffer allocation failure";
            }else{
                // Get system information, store in buffer
                if (sysctl(mgmtInfoBase, 6, msgBuffer, &length, NULL, 0) < 0){
                    errorFlag = @"sysctl msgBuffer failure";
                }
            }
        }
    }
    // Befor going any further...
    if (errorFlag != NULL){
        NSLog(@"Error: %@", errorFlag);
        if(NULL != msgBuffer){
            free(msgBuffer);
        }
        return errorFlag;
    }
    // Map msgbuffer to interface message structure
    interfaceMsgStruct = (struct if_msghdr *) msgBuffer;
    // Map to link-level socket structure
    socketStruct = (struct sockaddr_dl *) (interfaceMsgStruct + 1);
    // Copy link layer address data in socket structure to an array
    memcpy(&macAddress, socketStruct->sdl_data + socketStruct->sdl_nlen, 6);
    // Read from char array into a string object, into traditional Mac address format
    NSString *macAddressString = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                                  macAddress[0], macAddress[1], macAddress[2],
                                  macAddress[3], macAddress[4], macAddress[5]];
    //NSLog(@"Mac Address: %@", macAddressString);
    // Release the buffer memory
    free(msgBuffer);
    return macAddressString;
}

+ (NSData*)gzip:(NSData*)pUncompressedData error:(NSError **)error;{
    if ([pUncompressedData length]){
        float level = -1.0f;
        z_stream stream;
        stream.zalloc = Z_NULL;
        stream.zfree = Z_NULL;
        stream.opaque = Z_NULL;
        stream.avail_in = (uint)[pUncompressedData length];
        stream.next_in = (Bytef *)[pUncompressedData bytes];
        stream.total_out = 0;
        stream.avail_out = 0;
        
        int compression = (level < 0.0f)? Z_DEFAULT_COMPRESSION: (int)roundf(level * 9);
        if (deflateInit2(&stream, compression, Z_DEFLATED, 31, 8, Z_DEFAULT_STRATEGY) == Z_OK){
            NSMutableData *outdata = [NSMutableData dataWithLength:8192];
            while (stream.avail_out == 0){
                if (stream.total_out >= [outdata length]){
                    outdata.length += 8192;
                }
                stream.next_out = [outdata mutableBytes] + stream.total_out;
                stream.avail_out = (uint)([outdata length] - stream.total_out);
                deflate(&stream, Z_FINISH);
            }
            deflateEnd(&stream);
            outdata.length = stream.total_out;
            return outdata;
        }
        *error = [NSError errorWithDomain:@"openlog.error" code:-2 userInfo:@{@"NSLocalizedDescription":@"Failed to init gunzip."}];
        return nil;
    }
    *error = [NSError errorWithDomain:@"openlog.error" code:-3 userInfo:@{@"NSLocalizedDescription":@"inData should not be nil"}];
    return nil;
}
+ (NSData*)gunzip:(nonnull NSData*)pcompressedData error:(NSError **)error;{
    if ([pcompressedData length]){
        NSData* outdata = NULL;
        z_stream stream;
        stream.zalloc = Z_NULL;
        stream.zfree = Z_NULL;
        stream.avail_in = (uint)[pcompressedData length];
        stream.next_in = (Bytef *)[pcompressedData bytes];
        stream.total_out = 0;
        stream.avail_out = 0;
        
        NSMutableData *data = [NSMutableData dataWithLength: [pcompressedData length] * 1.5];
        if (inflateInit2(&stream, 47) == Z_OK){
            int status = Z_OK;
            while (status == Z_OK){
                if (stream.total_out >= [data length]){
                    data.length += [pcompressedData length] * 0.5;
                }
                stream.next_out = [data mutableBytes] + stream.total_out;
                stream.avail_out = (uint)([data length] - stream.total_out);
                status = inflate (&stream, Z_SYNC_FLUSH);
            }
            if (inflateEnd(&stream) == Z_OK){
                if (status == Z_STREAM_END){
                    data.length = stream.total_out;
                    outdata = data;
                    return outdata;
                }else{
                    *error = [NSError errorWithDomain:@"openlog.error" code:status userInfo:@{@"NSLocalizedDescription":[NSString stringWithFormat:@"Gunzip failed with status == :%d",status]}];
                    return nil;
                }
            }else{
                NSLog(@"Gunzip inflateEnd failed.");
                *error = [NSError errorWithDomain:@"openlog.error" code:-1 userInfo:@{@"NSLocalizedDescription":@"Gunzip inflateEnd failed."}];
                return nil;
            }
        }else{
            *error = [NSError errorWithDomain:@"openlog.error" code:-2 userInfo:@{@"NSLocalizedDescription":@"Failed to init gunzip."}];
            return nil;
        }
    }
    *error = [NSError errorWithDomain:@"openlog.error" code:-3 userInfo:@{@"NSLocalizedDescription":@"inData should not be nil"}];
    return nil;
}
@end
