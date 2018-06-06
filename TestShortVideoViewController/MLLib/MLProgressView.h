//
//  MLProgressView.h
//  TestFrameWork
//
//  Created by 周明亮 on 2018/6/5.
//  Copyright © 2018年 BBlink. All rights reserved.
//



#import <UIKit/UIKit.h>

@interface MLProgressView : UIView

@property (assign, nonatomic) NSInteger timeMax;

/**
 清除绘制路径
 */
- (void)clearProgress;

@end
