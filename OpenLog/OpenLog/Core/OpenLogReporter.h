//
//  OpenLogReporter.h
//  OpenLog
//
//  Created by bellchen on 2017/3/9.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>
@class OpenLogModel,OpenLogPingModel;
@interface OpenLogReporter : NSObject
- (void)reportLog:(OpenLogModel*)log complete:(void(^)(BOOL))completeBlock;
- (void)reportLogs:(NSArray<NSString*>*)logContents complete:(void(^)(BOOL))completeBlock;
- (OpenLogPingModel*)ping:(NSArray<NSString*>*)urlArray;
+ (instancetype)shareInstance;
@end
