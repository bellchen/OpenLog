//
//  OpenLogStorage.m
//  OpenLog
//
//  Created by bellchen on 2017/3/9.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLogStorage.h"
#import <sqlite3.h>
#import "OpenLogJsonKit.h"
#import "OpenLog.h"
#import "OpenLogModel.h"
#import "OpenLogHelper.h"
@implementation OpenLogStorageModel

@end

@implementation OpenLogOnlineConfigure
- (void)encode:(NSMutableDictionary *)dic{
    if (!dic) {
        return;
    }
    dic[@"v"] = @(self.version);//仅上报配置的版本号，详细信息需要服务端根据版本号找出全部内容
}
- (BOOL)decode:(NSDictionary *)dic{
    if (!dic) {
        return NO;
    }
    NSDictionary *content = dic[@"c"];
    NSNumber *version = dic[@"v"];
    NSString *md5 = dic[@"m"];
    if (!content ||
        ![content isKindOfClass:[NSDictionary class]]) {
        return NO;
    }
    if (!version ||
        ![version isKindOfClass:[NSNumber class]]) {
        return NO;
    }
    if (!md5 ||
        ![md5 isKindOfClass:[NSString class]]) {
        return NO;
    }
    self.content = [content jsonString];
    self.version = version.integerValue;
    self.md5 = md5;
    return YES;
}
@end

typedef NS_ENUM(NSInteger, OpenLogStorageStatus) {
    OpenLogStorageStatusNotSent = 1,
    OpenLogStorageStatusSending = 2,
};
static const char* kCreateLogTable = "create table if not exists logs(logId INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL, content TEXT, status INTEGER, retry INTEGER, timestamp INTEGER)";
static const char* kCreateUserTable = "create table if not exists user(uid TEXT, userType INTEGER, appVersion TEXT, tagTime INTEGER, PRIMARY KEY(uid))";
static const char* kCreateConfigTable = "create table if not exists config(type INTEGER, content TEXT, md5 TEXT, version INTEGER, PRIMARY KEY(type))";
static NSInteger kCurrentSDKDatabaseVersion = 1;
static NSString *kSDKDatabaseVersionKey = @"__OpenLogSDKDatabaseVersion__";
static NSString *kLockString = @"__OpenLogLock__";
@interface OpenLogStorage ()
@property (assign, nonatomic) dispatch_queue_t taskQueue;
@property (assign, nonatomic) sqlite3* db;
@property (assign, nonatomic) NSInteger numberOfStoredLog;
@end
@implementation OpenLogStorage
static OpenLogStorage *instance = nil;
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
    [self initDb];
    return self;
}
- (void)start{
    if(self.db != NULL){
        dispatch_async(self.taskQueue, ^{
            [self updateDatabase:"update logs set status=%d  where status = %d", OpenLogStorageStatusNotSent, OpenLogStorageStatusSending];
            self.numberOfStoredLog = [self selectCountOfLogs];
        });
    }
}
- (void)stop;{
    [self closeDB];
}
#pragma mark - logs
- (void)sendCachedLogs:(NSInteger)maxCount{
    
}
- (void)storeLog:(OpenLogModel *)log complete:(void (^)())completeBlock{
    
}
-(uint32_t)selectCountOfLogs{
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:1];
    
    sqlite3 * db = self.db;
    
    if(db != NULL){
        int ret = [self executeQuery:db result:result fmt:"select count(*) from logs where status=%d",OpenLogStorageStatusNotSent];
        if(ret == SQLITE_OK){
            if(result.count == 1){
                NSMutableArray* row = result[0];
                if(row.count == 1){
                    uint32_t v = [row[0] intValue];
                    if([[OpenLogConfigure shareInstance] debug]){
                        NSLog(@"%d unsent events.", v);
                    }
                    return v;
                }
            }
        }
    }
    return 0;
}
- (void)deleteLogs:(NSArray<OpenLogStorageModel*>*)logs{
    dispatch_async(self.taskQueue, ^{
        NSEnumerator *logsEnumerator = logs.objectEnumerator;
        OpenLogStorageModel* log;
        BOOL useTransaction = logs.count > 1;
        BOOL success = FALSE;
        @try{
            if(useTransaction){
                [self updateDatabase:"BEGIN TRANSACTION"];
            }
            while (log = logsEnumerator.nextObject) {
                int ret = [self updateDatabase:"delete from logs where logId = %d", log.logId];
                if(ret != SQLITE_OK){
                    success = FALSE;
                    break;
                }
            }
            success = TRUE;
        }@finally {
            if(useTransaction){
                if(success){
                    [self updateDatabase:"END TRANSACTION"];
                }else{
                    [self updateDatabase:"ROLLBACK"];
                }
            }
        }
        self.numberOfStoredLog = [self selectCountOfLogs];
    });
}
-(void)updateSendFailedLogs:(NSArray<OpenLogStorageModel*>*)logs{
    dispatch_async(self.taskQueue, ^{
        NSEnumerator *logsEnumerator = logs.objectEnumerator;
        OpenLogStorageModel* log;
        BOOL useTransaction = logs > 1;
        BOOL success = FALSE;
        @try{
            if(useTransaction){
                [self updateDatabase:"BEGIN TRANSACTION"];
            }
            while (log = logsEnumerator.nextObject) {
                log.retry = log.retry +1;
                int ret = -1;
                if(log.retry >= [[OpenLogConfigure shareInstance] reportRetryMax]){
                    ret = [self updateDatabase:"delete from logs where logId = %d", log.logId];
                }else{
                    ret = [self updateDatabase:"update logs set status=%d,retry=%d where logId = %d", OpenLogStorageStatusNotSent,log.retry, log.logId];
                }
                if(ret != SQLITE_OK){
                    success = FALSE;
                    break;
                }
            }
            success = TRUE;
        }@finally {
            if(useTransaction){
                if(success){
                    [self updateDatabase:"END TRANSACTION"];
                }else{
                    [self updateDatabase:"ROLLBACK"];
                }
            }
        }
        self.numberOfStoredLog = [self selectCountOfLogs];
    });
}

-(void)updateEvents:(NSArray<OpenLogStorageModel*>*)logs status:(OpenLogStorageStatus)status{
    dispatch_async(self.taskQueue, ^{
        NSEnumerator *logsEnumerator = logs.objectEnumerator;
        OpenLogStorageModel* log;
        BOOL useTransaction = logs.count > 1;
        BOOL success = FALSE;
        @try{
            if(useTransaction){
                [self updateDatabase:"BEGIN TRANSACTION"];
            }
            int ret = -1;
            while (log = logsEnumerator.nextObject) {
                ret = [self updateDatabase:"update logs set status = %d where logId = %d", status,log.logId];
                if(ret != SQLITE_OK){
                    success = FALSE;
                    break;
                }
            }
            success = TRUE;
        }@finally {
            if(useTransaction){
                if(success){
                    [self updateDatabase:"END TRANSACTION"];
                }else{
                    [self updateDatabase:"ROLLBACK"];
                }
            }
        }
        self.numberOfStoredLog = [self selectCountOfLogs];
    });
}
- (NSInteger)storedLogCount{
    return self.numberOfStoredLog;
}
- (void)loadCacheLogs:(NSMutableArray*)logs{
    uint32_t reportLogLength = [[OpenLogConfigure shareInstance] reportLogLength];
    NSMutableArray* result = [NSMutableArray arrayWithCapacity:reportLogLength];
    
    sqlite3* db = self.db;
    
    if(db != NULL){
        int ret = [self executeQuery:db result:result fmt:"select logId,content,status,retry,timestamp from logs where status = %d order by timestamp limit %d",OpenLogStorageStatusNotSent,reportLogLength];
        if(ret == SQLITE_OK && result.count > 0){
            NSEnumerator *enumerator = [result objectEnumerator];
            NSMutableArray* row;
            while (row = enumerator.nextObject) {
                if(row.count == 5){
                    OpenLogStorageModel* storageModel = [[OpenLogStorageModel alloc]init];
                    storageModel.logId = [row[0] integerValue];
                    storageModel.content = row[1];
                    storageModel.status = [row[2] integerValue];
                    storageModel.retry = [row[3] integerValue];
                    storageModel.timestamp = [row[4] integerValue];
                    [logs addObject:storageModel];
                }
            }
        }
    }
}
#pragma mark - user
- (void)storeUser:(OpenLogUser *)user{
    if (!user) {
        return;
    }
    dispatch_async(self.taskQueue, ^{
        [self updateDatabase:"update user set userType=%d, appVersion='%s', tagTime=%u where uid='%s'",user.userType,  [user.appVersion cStringUsingEncoding:NSUTF8StringEncoding ],  user.tagTime,[user.uid cStringUsingEncoding:NSUTF8StringEncoding]];
    });
}
- (OpenLogUser*)loadUser{
    __block OpenLogUser* user = nil;
    dispatch_sync(self.taskQueue, ^{//同步获取user
        NSMutableArray* result = [NSMutableArray arrayWithCapacity:1];
        
        sqlite3* db = self.db;
        
        if(db != NULL){
            int ret = [self executeQuery:db result:result fmt:"select uid,userType,appVersion,tagTime from user"];
            if(ret == SQLITE_OK){
                if(result.count == 0){
                    user = [[OpenLogUser alloc]init];
                    user.uid = [OpenLogHelper shareInstance].device.deviceid;
                    user.userType = OpenLogUserTypeNew;
                    user.appVersion = [OpenLogHelper shareInstance].device.appVersion;
                    user.tagTime = [[NSDate date] timeIntervalSince1970];
                    [self updateDatabase:"insert into user values('%s', %u, '%s', %u)", [user.uid cStringUsingEncoding:NSUTF8StringEncoding],user.userType, [user.appVersion cStringUsingEncoding:NSUTF8StringEncoding ],  user.tagTime];
                }
                if(result.count == 1){
                    NSMutableArray* row = result.firstObject;
                    if(nil != row && row.count == 4){
                        user = [[OpenLogUser alloc]init];
                        user.uid = row[0];
                        user.userType = [row[1] integerValue];
                        user.appVersion = row[2];
                        user.tagTime = [row[3] integerValue];
                    }
                }
            }
        }
    });
    return user;
}
#pragma mark - configure
- (void)storeConfigure:(OpenLogOnlineConfigure *)onlineConfig{
    
}
- (void)loadConfigure:(void (^)(OpenLogOnlineConfigure *))completeBlock{
    
}
#pragma mark - other
- (dispatch_queue_t)taskQueue{
    if (!_taskQueue) {
        _taskQueue = dispatch_queue_create("OpenLogStorageQueue", NULL);
    }
    return _taskQueue;
}
- (void)initDb{
    if(self.db == NULL){
        NSLog(@"NULL database to init table.");
        return;
    }
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSInteger sdk_db_ver = [userDefaults integerForKey:kSDKDatabaseVersionKey];
    if(sdk_db_ver == 0){
        [userDefaults setInteger:kCurrentSDKDatabaseVersion forKey:kSDKDatabaseVersionKey];
        [userDefaults synchronize];
    }else{
        if(sdk_db_ver < kCurrentSDKDatabaseVersion){
            //implement upgrade database logic here
        }
    }
    [self executeUpdate:_db fmt:kCreateLogTable];
    [self executeUpdate:_db fmt:kCreateUserTable];
    [self executeUpdate:_db fmt:kCreateConfigTable];
}
- (sqlite3*)db{
    if (_db == NULL) {
        NSString *documentPath=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *oldDatabaseFilePath=[documentPath stringByAppendingPathComponent:@"openlog.db"];
        NSString *databaseFilePath=[documentPath stringByAppendingPathComponent:@".openlog.db"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        if([fileManager fileExistsAtPath:oldDatabaseFilePath]){
            if([fileManager fileExistsAtPath:databaseFilePath]){
                [self deleteDB];
            }
            
            NSError *error;
            if ([fileManager moveItemAtPath:oldDatabaseFilePath toPath:databaseFilePath error:&error] != YES){
                NSLog(@"Unable to move file: %@", [error localizedDescription]);
            }
        }
        
        if (sqlite3_open([databaseFilePath UTF8String], &_db)!=SQLITE_OK) {
            _db = NULL;
        }
    }
    return _db;
}

- (void)deleteDB{
    [self closeDB];
    NSString *documentPath=[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *databaseFilePath=[documentPath stringByAppendingPathComponent:@".openlog.db"];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error = nil;
    BOOL removeSuccess = [fileManager removeItemAtPath:databaseFilePath error:&error];
    if (!removeSuccess || error) {
        NSLog(@"Delete database failed reason:%@", error);
    }
}
-(void)closeDB{
    if(_db != NULL){
        sqlite3_close(_db);
        _db = nil;
    }
}
-(int)updateDatabase:(const char*) fmt, ...{
    va_list args;
    va_start(args, fmt);
    char szSQL[1024];
    vsnprintf(szSQL, sizeof(szSQL) - 1, fmt, args);
    va_end(args);
    
    sqlite3* db = self.db;
    
    if(db != NULL){
        int ret = [self executeUpdate:db sql:szSQL];
        if(ret == SQLITE_CORRUPT){
            [self deleteDB];
            [self initDb];
        }
        return ret;
    }
    return -1;
}
- (int)executeUpdate:(sqlite3*)db sql:(const char*)sql{
    if(db == NULL){
        return -1;
    }
    char* errMsg = NULL;
    @synchronized(kLockString){
        int ret = sqlite3_exec(db, sql, 0, 0, &errMsg);
        if (ret != SQLITE_OK){
            NSLog(@"Failed to execute sql:%s for reason:%s", sql, errMsg);
            sqlite3_free(errMsg);
            return ret;
        }
        return ret;
    }
}
- (int)executeUpdate:(sqlite3*)db fmt:(const char*)fmt, ...{
    if(db == NULL){
        return -1;
    }
    va_list ap;
    va_start(ap, fmt);
    char szSQL[1024];
    vsnprintf(szSQL, sizeof(szSQL) - 1, fmt, ap);
    char* errMsg = NULL;
    @synchronized(kLockString){
        int ret = sqlite3_exec(db, szSQL, 0, 0, &errMsg);
        va_end(ap);
        if (ret != SQLITE_OK){
            NSLog(@"Failed to execute sql:%s for reason:%s", szSQL, errMsg);
            sqlite3_free(errMsg);
            return ret;
        }
        return ret;
    }
}
static int queryCallback(void* data, int n_columns,
                         char** column_values, char** column_names)
{
    NSMutableArray* res = (__bridge NSMutableArray*) data;
    if (NULL != column_values && n_columns > 0 && column_values[0] != NULL){
        NSMutableArray* row = [NSMutableArray arrayWithCapacity:n_columns];
        for(int i = 0;i < n_columns; i++){
            NSString* v = [NSString stringWithCString:column_values[i] encoding:NSUTF8StringEncoding];
            [row addObject:v] ;
        }
        [res addObject:row];
    }
    return 0;
}
- (int)executeQuery:(sqlite3*)db result:(NSMutableArray*)result fmt:(const char*)fmt, ...{
    if(db == NULL || !result){
        return -1;
    }
    va_list ap;
    va_start(ap, fmt);
    char szSQL[1024];
    vsnprintf(szSQL, sizeof(szSQL) - 1, fmt, ap);
    char* errMsg = NULL;
    
    @synchronized(kLockString){
        int ret = sqlite3_exec(db, szSQL, queryCallback,
                               (__bridge void *)(result), &errMsg);
        va_end(ap);
        if (ret != SQLITE_OK){
            NSLog(@"Failed to execute sql:%s for reason:%s", szSQL, errMsg);
            sqlite3_free(errMsg);
            return ret;
        }
        return ret;
    }
}
@end
