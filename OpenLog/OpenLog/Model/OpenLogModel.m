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
@implementation OpenLogPingModel
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
    
}
- (NSString*)toJsonString{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    NSString *appKey = [OpenLogHelper shareInstance].appKey;
    if (self.appKey) {
        appKey = self.appKey;
    }
    data[@"ts"] = @(self.timestamp);
    data[@"sid"] = @(self.sessionID);
    static NSInteger kSeq = 1;
    data[@"idx"] = @(kSeq);
    kSeq++;
    
    return nil;
}
@end
