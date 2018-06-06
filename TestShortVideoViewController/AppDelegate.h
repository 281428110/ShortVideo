//
//  AppDelegate.h
//  TestShortVideoViewController
//
//  Created by 周明亮 on 2018/6/5.
//  Copyright © 2018年 DaQi. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

