//
//  OpenLogHelper.h
//  OpenLog
//
//  Created by bellchen on 2017/3/9.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, OpenLogOnlineConfigType) {
    OpenLogOnlineConfigTypeSDK = 1,
    OpenLogOnlineConfigTypeApp,
};
@class OpenLogDevice,OpenLogUser,OpenLogOnlineConfigure;
@interface OpenLogHelper : NSObject
@property (copy, nonatomic) NSString *appKey;
@property (strong, nonatomic) OpenLogUser *user;
@property (strong, nonatomic) OpenLogDevice *device;
+ (instancetype)shareInstance;
- (BOOL)checkOpenLogEnable;
- (NSString*)appOnlineConfigForKey:(NSString*)key;
- (void)updateOnlineConfig:(NSDictionary*)onlineConfig;
- (OpenLogOnlineConfigure*)onlineConfigureForType:(OpenLogOnlineConfigType)type;
+ (NSString*)macAddress;
+ (NSData*)gzip:(nonnull NSData*)data error:(NSError **)error;
+ (NSData*)gunzip:(NSData*)data error:(NSError **)error;
@end
