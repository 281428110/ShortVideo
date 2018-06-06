//
//  MLShortVideoViewController.h
//  TestShortVideoViewController
//
//  Created by 周明亮 on 2018/6/5.
//  Copyright © 2018年 DaQi. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef void(^TakeOperationSureBlock)(NSURL *item , UIImage *image);

@interface MLShortVideoViewController : UIViewController

/**
    调用block 返回视频本地路径 以及封面的图片
 */
@property (copy, nonatomic) TakeOperationSureBlock takeBlock;

@end
