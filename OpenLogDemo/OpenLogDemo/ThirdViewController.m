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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
- (IBAction)backToIndexAction:(id)sender {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
