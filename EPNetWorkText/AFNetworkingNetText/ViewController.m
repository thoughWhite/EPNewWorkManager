//
//  ViewController.m
//  AFNetworkingNetText
//
//  Created by 邢大象 on 16/3/15.
//  Copyright © 2016年 邢大象. All rights reserved.
//

#import "ViewController.h"
#import "EPNetWorkManager.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    EPNetWorkManager *manager = [EPNetWorkManager shareManager];
    [manager startMonoriting];
    
    [manager setNewWorkStatusChangeBlock:^(EPNetWorkStatus status) {
        NSLog(@"%ld",(long)status);
    }];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
