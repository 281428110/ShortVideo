//
//  ViewController.m
//  TestShortVideoViewController
//
//  Created by 周明亮 on 2018/6/5.
//  Copyright © 2018年 DaQi. All rights reserved.
//

#import "ViewController.h"
#import "MLShortVideoViewController.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    UIButton *btn = [[UIButton alloc]initWithFrame:CGRectMake(100, 200, 50, 50)];
    btn.backgroundColor = [UIColor blueColor];
    [btn addTarget:self action:@selector(click) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
}

- (void)click{
    MLShortVideoViewController *ctrl = [[MLShortVideoViewController alloc]init];
    ctrl.takeBlock = ^(id item, UIImage *image) {
        NSURL *videoURL = item;
        //视频url
        NSLog(@"---%@",videoURL);
        NSLog(@"++++%ld",image.size);
        
    };
    [self presentViewController:ctrl animated:YES completion:nil];
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
