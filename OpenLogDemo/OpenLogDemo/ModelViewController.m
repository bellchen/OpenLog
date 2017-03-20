//
//  ModelViewController.m
//  OpenLogDemo
//
//  Created by bellchen on 2017/3/19.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "ModelViewController.h"
#import "OpenLog.h"
@interface ModelViewController ()
@property (strong, nonatomic) IBOutlet UITextField *interfaceTextField;
@property (strong, nonatomic) IBOutlet UITextField *requestTextField;
@property (strong, nonatomic) IBOutlet UITextField *responseTextField;
@property (strong, nonatomic) IBOutlet UITextField *durationTextField;
@property (strong, nonatomic) IBOutlet UITextField *codeTextField;
@property (strong, nonatomic) IBOutlet UISlider *rateSlider;
@property (strong, nonatomic) IBOutlet UISegmentedControl *resultSegmentedControl;

@end

@implementation ModelViewController

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
- (IBAction)tapAction:(id)sender {
    [self.view endEditing:YES];
}
- (IBAction)doneAction:(id)sender {
    OpenLogInterfaceMonitor *monitor = [[OpenLogInterfaceMonitor alloc] init];
    monitor.interface = self.interfaceTextField.text;
    monitor.requestSize = [self.requestTextField.text integerValue];
    monitor.responseSize = [self.responseTextField.text integerValue];
    monitor.duration = [self.durationTextField.text integerValue];
    monitor.code = [self.codeTextField.text integerValue];
    monitor.samplingRate = self.rateSlider.value;
    monitor.resultType = self.resultSegmentedControl.selectedSegmentIndex;
    [[OpenLog shareInstance] onMonitor:monitor];
    [self dismissViewControllerAnimated:YES completion:nil];
}
- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
