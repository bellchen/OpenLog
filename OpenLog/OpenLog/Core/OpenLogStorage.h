//
//  OpenLogStorage.h
//  OpenLog
//
//  Created by bellchen on 2017/3/9.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@class OpenLogUser,OpenLogModel;
@interface OpenLogStorageModel : NSObject
@property (assign, nonatomic) NSInteger logID;
@property (strong, nonatomic) NSString *content;
@property (assign, nonatomic) NSInteger status;
@property (assign, nonatomic) NSInteger retry;
@property (assign, nonatomic) NSInteger timestamp;
@end

@interface OpenLogOnlineConfigure : NSObject
@property (assign, nonatomic) NSInteger type;
@property (strong, nonatomic) NSString *content;
@property (strong, nonatomic) NSString *md5;
@property (assign, nonatomic) NSInteger version;
- (void)encode:(NSDictionary*)dic;
- (BOOL)decode:(NSDictionary*)dic;
@end

@interface OpenLogStorage : NSObject
- (void)start;
- (void)stop;
- (OpenLogUser*)loadUser;
- (void)storeUser:(OpenLogUser*)user;
- (NSInteger)storedLogCount;
- (void)storeLog:(OpenLogModel*)log complete:(void(^)())completeBlock;
- (void)storeConfigure:(OpenLogOnlineConfigure*)onlineConfig;
- (void)loadConfigure:(void(^)(OpenLogOnlineConfigure*))completeBlock;
- (void)sendCachedLogs:(NSInteger)maxCount;
+ (instancetype)shareInstance;
@end
