# OpenLog
An open source SDK for iOS like umeng analytics 

OpenLog 是一个开源的数据统计SDK，项目依然在开发中，欢迎一起完善，欢迎其他端开发者参与进来

## 示例
初始化
```objc
@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[OpenLogConfigure shareInstance] setReportBlock:^(NSArray<NSString *> * contents) {
        NSLog(@"%@",contents);
    }];
    [OpenLogConfigure shareInstance].reportUrl = @"report.wentiertong.com";
    [OpenLogConfigure shareInstance].reportStrategy = OpenLogReportStrategyRealTime;
    [[OpenLog shareInstance] startWithAppKey:@"test key"];
    return YES;
}

@end 
```

页面统计
```objc
- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[OpenLog shareInstance] onPageBegin:NSStringFromClass([self class])];
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[OpenLog shareInstance] onPageEnd:NSStringFromClass([self class])];
}
```

错误采集(支持对NSException和NSError的采集)
```objc
- (IBAction)reportAnExceptionAction:(id)sender {
    @try {
        @throw [[NSException alloc] initWithName:@"want to play" reason:@"reading is boring" userInfo:@{}];
    } @catch (NSException *exception) {
        [[OpenLog shareInstance] onException:exception];
    } @finally {

    }
}
- (IBAction)reportAnErrorAction:(id)sender {
    [[OpenLog shareInstance] onError:@"here is an error message, you can get it from NSError's userInfo"];
}
```
更多示例请checkout demo

## 安装
cocoapods正在处理中，坐等我有空
