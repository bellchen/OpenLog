//
//  ViewController.m
//  OpenLogDemo
//
//  Created by bellchen on 2017/3/7.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "ViewController.h"
#import "OpenLog.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [[OpenLog shareInstance] onPageBegin:NSStringFromClass([self class])];
}
- (void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [[OpenLog shareInstance] onPageEnd:NSStringFromClass([self class])];
}
- (IBAction)reportALogNamedReadAction:(id)sender {
    [[OpenLog shareInstance] onLog:@"read"];
}
- (IBAction)reportABeginLogNamedReadAction:(id)sender {
    [[OpenLog shareInstance] onLogBegin:@"read"];
}
- (IBAction)reportAnEndLogNamedReadAction:(id)sender {
    [[OpenLog shareInstance] onLogEnd:@"read"];
}
- (IBAction)reportALogNamedReadSecondsAction:(id)sender {
    [[OpenLog shareInstance] onLog:@"read" duration:3];
}
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

@end
