//
//  OpenLogReporter.m
//  OpenLog
//
//  Created by bellchen on 2017/3/9.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLogReporter.h"
#import <netdb.h>
#import <arpa/inet.h>
#import "OpenLogModel.h"
#import "OpenLog.h"
#import "OpenLogAES128.h"
#import "OpenLogHelper.h"
#import "OpenLogJsonKit.h"
#import "OpenLogReachability.h"
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
- (void)reportLog:(OpenLogModel *)log complete:(void (^)(BOOL success))completeBlock{
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
    if (!urlArray ||
        ![urlArray isKindOfClass:[NSArray class]] ||
        urlArray.count == 0) {
        return nil;
    }
    OpenLogPingModel *pingModel = [[OpenLogPingModel alloc] init];
    @autoreleasepool {
        NSMutableString *pingContent = [[NSMutableString alloc] init];
        [pingContent appendString:@"["];
        NSUInteger count = urlArray.count;
        [urlArray enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            OpenLogPing *ping = [self pingUrl:[NSURL URLWithString:obj]];
            [pingContent appendString:[ping toJsonString]];
            if (idx != count -1) {
                [pingContent appendString:@","];
            }
        }];
        [pingContent appendString:@"]"];
        pingModel.ping = pingContent;
        pingModel.sim = [OpenLogHelper shareInstance].device.mccmnc;
        pingModel.network = [OpenLogHelper networkStatus];
    }
    return pingModel;
}
static sigjmp_buf jmpbuf;
static void alarm_func(){
    siglongjmp(jmpbuf, 1);
}

static struct hostent *timeGethostbyname(const char *domain, int timeout){
    struct hostent *ipHostent = NULL;
    signal(SIGALRM, alarm_func);
    if(sigsetjmp(jmpbuf, 1) != 0){
        alarm(0);//timout
        signal(SIGALRM, SIG_IGN);
        return NULL;
    }
    alarm(timeout);//setting alarm
    ipHostent = gethostbyname(domain);
    signal(SIGALRM, SIG_IGN);
    return ipHostent;
}
- (OpenLogPing*)pingUrl:(NSURL*)url{
    OpenLogPing *ping = [[OpenLogPing alloc] init];
    NSString *host = url.host;
    NSNumber *port = url.port;
    if (port) {
        port = @(80);
    }
    
    NSDate *dateBegin = [NSDate date];
    ping.domain = host;
    ping.port = port.integerValue;
    ping.timestamp = dateBegin.timeIntervalSince1970;
    int socketFileDescriptor = socket(AF_INET, SOCK_STREAM, 0);
    if (socketFileDescriptor == -1) {
        ping.success = NO;
        return ping;
    }
    struct hostent * remoteHostEnt = timeGethostbyname([host UTF8String],10);
    if (remoteHostEnt == NULL) {
        close(socketFileDescriptor);
        ping.success = NO;
        return ping;
    }
    struct in_addr **list = (struct in_addr **)remoteHostEnt->h_addr_list;
    NSString *addressString = [NSString stringWithCString:inet_ntoa(*list[0]) encoding:NSUTF8StringEncoding];
    
    struct in_addr * remoteInAddr = (struct in_addr *)remoteHostEnt->h_addr_list[0];
    
    struct sockaddr_in socketParameters;
    socketParameters.sin_family = AF_INET;
    socketParameters.sin_addr = *remoteInAddr;
    socketParameters.sin_port = htons([port intValue]);
    
    int ret = connect(socketFileDescriptor, (struct sockaddr *) &socketParameters, sizeof(socketParameters));
    if (ret == -1) {
        close(socketFileDescriptor);

        NSString * errorInfo = [NSString stringWithFormat:@" >> Failed to connect to %@:%@", host, port];
        NSLog(@"errorInfo socket. %@",errorInfo);
        ping.success = NO;
        return ping;
    }
    NSDate *dateEnd = [NSDate date];
    double timeDiff = [dateEnd timeIntervalSinceDate:dateBegin];
    ping.ip = addressString;
    ping.success = YES;
    ping.duration = timeDiff*100;
    close(socketFileDescriptor);
    return ping;
}
@end
