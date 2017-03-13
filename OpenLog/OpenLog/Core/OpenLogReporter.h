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
- (void)reportLogs:(NSArray<OpenLogModel*>*)logs complete:(void(^)(BOOL))completeBlock;
- (OpenLogPingModel*)ping:(NSArray<NSString*>*)urlArray;
+ (instancetype)shareInstance;
@end
