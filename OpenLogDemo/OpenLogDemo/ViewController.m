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
    [[OpenLog shareInstance] startWithAppKey:@"aa"];
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
@end
