//
//  MLAVPlayer.h
//  TestFrameWork
//
//  Created by 周明亮 on 2018/6/5.
//  Copyright © 2018年 BBlink. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MLAVPlayer : UIView

@property (copy, nonatomic) NSURL *videoUrl;


/**
 播放初始化

 @param frame 播放器的大小
 @param bgView 背景视图
 @param url 播放的Url
 @return
 */
- (instancetype)initWithFrame:(CGRect)frame withShowInView:(UIView *)bgView url:(NSURL *)url;

/**
 停止播放
 */
- (void)stopPlayer;

@end
