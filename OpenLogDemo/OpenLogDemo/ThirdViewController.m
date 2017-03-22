//
//  ThirdViewController.m
//  OpenLogDemo
//
//  Created by bellchen on 2017/3/19.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "ThirdViewController.h"
#import "OpenLog.h"
@interface ThirdViewController ()

@end

@implementation ThirdViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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

- (IBAction)backToIndexAction:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}
- (IBAction)reportSleepLogAction:(id)sender {
    [[OpenLog shareInstance] onLog:@"sleep" kvs:@{@"position":@"home",@"with":@"wife"}];
}
- (IBAction)reportSleepBeginLogAction:(id)sender {
    [[OpenLog shareInstance] onLogBegin:@"sleep" kvs:@{@"position":@"home",@"with":@"wife"}];
}
- (IBAction)reportSleepEndLogAction:(id)sender {
    [[OpenLog shareInstance] onLogEnd:@"sleep" kvs:@{@"position":@"home",@"with":@"wife"}];
}
- (IBAction)reportSleepLogWithTimeAction:(id)sender {
    [[OpenLog shareInstance] onLog:@"sleep" kvs:@{@"position":@"home",@"with":@"wife"} duration:8*60*60];
}
- (IBAction)startANewSessionAction:(id)sender {
    [[OpenLog shareInstance] startNewSession];
}
- (IBAction)reportAllLogAction:(id)sender {
    [[OpenLog shareInstance] reportLogs:-1];
}

@end
