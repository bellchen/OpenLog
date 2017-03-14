//
//  OpenLogReporter.m
//  OpenLog
//
//  Created by bellchen on 2017/3/9.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLogReporter.h"
#import "OpenLogModel.h"
#import "OpenLog.h"
#import "OpenLogAES128.h"
#import "OpenLogHelper.h"
#import "OpenLogJsonKit.h"
NSString * const kOpenLogReporterErrorDomain = @"openlog.reporter.error";
@interface OpenLogReporter ()
@property (assign, nonatomic) dispatch_queue_t taskQueue;
@end
@implementation OpenLogReporter
static OpenLogReporter *instance = nil;
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
    return self;
}
#pragma mark - report log
- (void)reportLog:(OpenLogModel *)log complete:(void (^)(BOOL))completeBlock{
    NSString *jsonString = [log toJsonString];
    if (jsonString.length > [OpenLogConfigure shareInstance].reportLogLength &&
        log.type != OpenLogModelTypeError) {
        if (completeBlock) {
            completeBlock(YES);
        }
    }
    if (jsonString) {
        [self reportLogs:@[jsonString] complete:completeBlock];
    }
}
- (void)reportLogs:(NSArray<NSString *> *)logContents complete:(void (^)(BOOL))completeBlock{
    if (!logContents ||
        ![logContents isKindOfClass:[NSArray class]] ||
        logContents.count ==0 ) {
        if (completeBlock) {
            completeBlock(NO);
        }
        return;
    }
    if ([OpenLogConfigure shareInstance].reportBlock) {
        [OpenLogConfigure shareInstance].reportBlock(logContents);
    }
    dispatch_async(self.taskQueue, ^{
        @autoreleasepool {
            NSMutableString *jsonString = [[NSMutableString alloc] init];
            [jsonString appendString:@"["];
            NSUInteger count = logContents.count;
            [logContents enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                [jsonString appendString:obj];
                if (idx != count -1) {
                    [jsonString appendString:@","];
                }
            }];
            [jsonString appendString:@"]"];
            NSData *requestData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
            [self sendRequest:requestData complete:^(NSData *data, NSError *error) {
                if (error || !data) {
                    if (completeBlock) {
                        completeBlock(NO);
                    }
                    return ;
                }
                @try {
                    NSDictionary *onlineConfig = [data objectFromJson];
                    if ([onlineConfig isKindOfClass:[NSDictionary class]]) {
                        [[OpenLogHelper shareInstance] updateOnlineConfig:onlineConfig];
                    }
                } @catch (NSException *exception) {
                    NSLog(@"[Error] catch Error:%@, %@",exception.name,exception.reason);
                }
            }];
        }
    });
}
- (void)sendRequest:(NSData*)requestData complete:(void (^)(NSData*,NSError*))completeBlock{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    request.HTTPMethod = @"POST";
    NSString *url = [OpenLogConfigure shareInstance].reportUrl;
    if (!url) {
        if (completeBlock) {
            completeBlock(nil,[NSError errorWithDomain:kOpenLogReporterErrorDomain code:999 userInfo:@{@"NSLocalizedDescription":@"reportUrl is nil"}]);
        }
        return ;
    }
    request.URL = [NSURL URLWithString:url];
    request.timeoutInterval = 10;
    [request setValue:@"json" forHTTPHeaderField:@"Content-Type"];
    [request setValue:@"keep-alive" forHTTPHeaderField:@"Connection"];
    NSString *token = [NSString stringWithFormat:@"%0.f",[[NSDate date] timeIntervalSince1970]];
    [request setValue:token forHTTPHeaderField:@"Token"];
    NSMutableData *body = nil;
    body = [NSMutableData dataWithData:requestData];
    NSString *cryptKey = [token stringByAppendingString:@"CuaVHKPhOyZdLi9XvMF16U"];
    body = [body encryptWithKey:cryptKey];
    if (!body) {
        if (completeBlock) {
            completeBlock(nil,[NSError errorWithDomain:kOpenLogReporterErrorDomain code:998 userInfo:@{@"NSLocalizedDescription":@"failed to encrypt body"}]);
        }
        return ;
    }
    [request setValue:@"aes128" forHTTPHeaderField:@"Content-Encoding"];
    if (body.length >= 256) {
        NSData* compressedBody = [OpenLogHelper gzip:body error:nil];
        if (compressedBody) {
            body = [NSMutableData dataWithCapacity:compressedBody.length+4];
            uint32_t len = (uint32_t)requestData.length;
            len = htonl(len);
            [body appendBytes:&len length:sizeof(len)];
            [body appendData:compressedBody];
            [request setValue:@"aes128,gzip" forHTTPHeaderField:@"Content-Encoding"];
        }
    }
    request.HTTPBody = body;
    NSHTTPURLResponse *response = nil;
    NSError *error = nil;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        if (!error || !data) {
            if (completeBlock) {
                completeBlock(data,error);
            }
            return ;
        }
        if (response && [response isKindOfClass:[NSHTTPURLResponse class]]) {
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse*)response;
            if (httpResponse.statusCode != 200) {
                NSString *localizedDescription = [NSString stringWithFormat:@"[Warn]Receive invalid response:%zd",httpResponse.statusCode];
                if (data) {
                    localizedDescription = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
                }
                NSError *error = [NSError errorWithDomain:kOpenLogReporterErrorDomain code:httpResponse.statusCode userInfo:@{@"NSLocalizedDescription":localizedDescription}];
                if (completeBlock) {
                    completeBlock(data,error);
                }
                return ;
            }
            //TODO: test whether there is already gunzip data by NSURLSession
            NSString* encoding = [httpResponse.allHeaderFields objectForKey:@"Content-Encoding"];
            if (encoding &&
                [encoding rangeOfString:@"aes128" options:NSCaseInsensitiveSearch].location != NSNotFound) {
                data = [data decryptWithKey:cryptKey];
                if (completeBlock) {
                    completeBlock(data,nil);
                }
            }
        }
    }];
    [task resume];
}
- (dispatch_queue_t)taskQueue{
    if (!_taskQueue) {
        _taskQueue = dispatch_queue_create("OpenLogReporterQueue", NULL);
    }
    return _taskQueue;
}
#pragma mark - ping
- (OpenLogPingModel*)ping:(NSArray<NSString*>*)urlArray;{
    return nil;
}
@end
