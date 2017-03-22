//
//  SecondViewController.m
//  OpenLogDemo
//
//  Created by bellchen on 2017/3/19.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "SecondViewController.h"
#import "OpenLog.h"
@interface SecondViewController ()

@end

@implementation SecondViewController

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
- (IBAction)reportPlayLogAction:(id)sender {
    [[OpenLog shareInstance] onLog:@"play" args:@[@"开心消消乐",@"王者荣耀"]];
}

- (IBAction)reportPlayBeginLogAction:(id)sender {
    [[OpenLog shareInstance] onLogBegin:@"play" args:@[@"开心消消乐",@"王者荣耀"]];
}
- (IBAction)reportPlayEndLogAction:(id)sender {
    [[OpenLog shareInstance] onLogEnd:@"play" args:@[@"开心消消乐",@"王者荣耀"]];
}
- (IBAction)reportLogWithPlayTimeAction:(id)sender {
    [[OpenLog shareInstance]onLog:@"play" args:@[@"开心消消乐",@"王者荣耀"] duration:60*60];
}
- (IBAction)reportGameInfo:(id)sender {
    NSDictionary *gameInfo = @{@"name":@"王者荣耀",@"score":@99};
    [[OpenLog shareInstance] onAddition:gameInfo];
}

@end
