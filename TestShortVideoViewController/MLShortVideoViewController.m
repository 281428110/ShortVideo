//
//  MLShortVideoViewController.m
//  TestShortVideoViewController
//
//  Created by 周明亮 on 2018/6/5.
//  Copyright © 2018年 DaQi. All rights reserved.
//

#import "MLShortVideoViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "MLAVPlayer.h"
#import "MLProgressView.h"
#import <Foundation/Foundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "Masonry.h"

//状态条的高
#define StatusBarHeight [[UIApplication sharedApplication] statusBarFrame].size.height
//得到屏幕bounds
#define SCREEN_SIZE [UIScreen mainScreen].bounds
//得到屏幕height
#define SCREEN_HEIGHT [UIScreen mainScreen].bounds.size.height
//得到屏幕width
#define SCREEN_WIDTH [UIScreen mainScreen].bounds.size.width

typedef void(^PropertyChangeBlock)(AVCaptureDevice *captureDevice);
@interface MLShortVideoViewController ()<AVCaptureFileOutputRecordingDelegate>

@property (nonatomic, strong) UILabel *labelTipTitle;         //按住拍摄小视频的提示语
@property (nonatomic, strong) UIButton *btnBack;              //返回上个页面的按钮
@property (nonatomic, strong) UIButton *btnAfresh;            //重新录制小视频按钮
@property (nonatomic, strong) UIButton *btnEnsure;            //确定保存小视频到本地
@property (nonatomic, strong) UIButton *btnCamera;            //摄像头前后切换按钮
@property (nonatomic, strong) UIImageView *bgView;            //背景图片（加载的第一个父视图）
@property (nonatomic, assign) NSInteger seconds;              //记录录制的时间 默认最大10秒
@property (nonatomic, strong) NSURL *saveVideoUrl;            //记录需要保存视频的路径
@property (nonatomic, strong) MLAVPlayer *player;             //视频播放
@property (nonatomic, strong) MLProgressView *progressView;   //录制时的进度条
@property (nonatomic, assign) BOOL isVideo;                   //是否是摄像 YES 代表是录制
@property (nonatomic, strong) UIImageView *imgRecord;         //录制的按钮
@property (nonatomic, assign) NSInteger HSeconds;             //默认10秒的总录制时间
@property (nonatomic, strong) AVCaptureSession *session;                            //负责输入和输出设备之间的数据传递
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;             //图像预览层，实时显示捕获的图像
@property (nonatomic, strong) AVCaptureMovieFileOutput *captureMovieFileOutput;     //视频输出流
@property (nonatomic, strong) AVCaptureDeviceInput *captureDeviceInput;             //负责从AVCaptureDevice获得输入数据
@property (nonatomic, assign) UIBackgroundTaskIdentifier backgroundTaskIdentifier;  //后台任务标识
@property (nonatomic ,assign) UIBackgroundTaskIdentifier lastBackgroundTaskIdentifier;
@end

//时间大于这个就是视频
#define TimeMax 1

@implementation MLShortVideoViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.HSeconds = 10;
    [self dq_layoutSubViews];
     [self performSelector:@selector(hiddenTipsLabel) withObject:nil afterDelay:4];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:YES];
    [self customCamera];
    [self.session startRunning];
}
-(void)viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    [self.session stopRunning];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[UIApplication sharedApplication] setStatusBarHidden:NO];
}


- (void)hiddenTipsLabel {
    self.labelTipTitle.hidden = YES;
}


/**
 相机的输入设备的设置
 */
- (void)customCamera {
    self.session = [[AVCaptureSession alloc] init];//初始化会话，用来结合输入输出
    //设置分辨率 (设备支持的最高分辨率)
    if ([self.session canSetSessionPreset:AVCaptureSessionPresetHigh]) {
        self.session.sessionPreset = AVCaptureSessionPresetHigh;
    }
    //取得后置摄像头
    AVCaptureDevice *captureDevice = [self getCameraDeviceWithPosition:AVCaptureDevicePositionBack];
    //添加一个音频输入设备
    AVCaptureDevice *audioCaptureDevice=[[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
    
    //初始化输入设备
    NSError *error = nil;
    self.captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    //添加音频
    error = nil;
    AVCaptureDeviceInput *audioCaptureDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:audioCaptureDevice error:&error];
    if (error) {
        NSLog(@"取得设备输入对象时出错，错误原因：%@",error.localizedDescription);
        return;
    }
    self.captureMovieFileOutput = [[AVCaptureMovieFileOutput alloc] init];//视频输出
    //将输入设备添加到会话
    if ([self.session canAddInput:self.captureDeviceInput]) {
        [self.session addInput:self.captureDeviceInput];
        [self.session addInput:audioCaptureDeviceInput];
        //设置视频防抖
        AVCaptureConnection *connection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeVideo];
        if ([connection isVideoStabilizationSupported]) {
            connection.preferredVideoStabilizationMode = AVCaptureVideoStabilizationModeCinematic;
        }
    }
    //将输出设备添加到会话 (刚开始 是照片为输出对象)
    if ([self.session canAddOutput:self.captureMovieFileOutput]) {
        [self.session addOutput:self.captureMovieFileOutput];
    }
    //创建视频预览层，用于实时展示摄像头状态
    self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
    self.previewLayer.frame = self.view.bounds;//CGRectMake(0, 0, self.view.width, self.view.height);
    self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;//填充模式
    [self.bgView.layer addSublayer:self.previewLayer];
    [self addNotificationToCaptureDevice:captureDevice];
    [self.bgView bringSubviewToFront:self.btnEnsure];
    [self.bgView bringSubviewToFront:self.btnCamera];
    [self.bgView bringSubviewToFront:self.btnBack];
    [self.bgView bringSubviewToFront:self.imgRecord];
    [self.bgView bringSubviewToFront:self.labelTipTitle];
    [self.bgView bringSubviewToFront:self.progressView];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ([[touches anyObject] view] == self.imgRecord) {
        NSLog(@"开始录制");
        //根据设备输出获得连接
        AVCaptureConnection *connection = [self.captureMovieFileOutput connectionWithMediaType:AVMediaTypeAudio];
        //根据连接取得设备输出的数据
        if (![self.captureMovieFileOutput isRecording]) {
            //如果支持多任务则开始多任务
            if ([[UIDevice currentDevice] isMultitaskingSupported]) {
                self.backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];
            }
            if (self.saveVideoUrl) {
                [[NSFileManager defaultManager] removeItemAtURL:self.saveVideoUrl error:nil];
            }
            //预览图层和视频方向保持一致
            connection.videoOrientation = [self.previewLayer connection].videoOrientation;
            NSString *outputFielPath=[NSTemporaryDirectory() stringByAppendingString:@"myMovie.mov"];
            NSLog(@"save path is :%@",outputFielPath);
            NSURL *fileUrl=[NSURL fileURLWithPath:outputFielPath];
            NSLog(@"fileUrl:%@",fileUrl);
            [self.captureMovieFileOutput startRecordingToOutputFileURL:fileUrl recordingDelegate:self];
        } else {
            [self.captureMovieFileOutput stopRecording];
        }
    }
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if ([[touches anyObject] view] == self.imgRecord) {
        NSLog(@"结束触摸");
        if (!self.isVideo) {
            [self performSelector:@selector(endRecord) withObject:nil afterDelay:0.3];
        } else {
            [self endRecord];
        }
    }
}
- (void)endRecord {
    [self.captureMovieFileOutput stopRecording];//停止录制
}

//给输入设备添加通知
-(void)addNotificationToCaptureDevice:(AVCaptureDevice *)captureDevice{
    //注意添加区域改变捕获通知必须首先设置设备允许捕获
    [self changeDeviceProperty:^(AVCaptureDevice *captureDevice) {
        captureDevice.subjectAreaChangeMonitoringEnabled=YES;
    }];
}
//属性改变操作
-(void)changeDeviceProperty:(PropertyChangeBlock)propertyChange{
    AVCaptureDevice *captureDevice= [self.captureDeviceInput device];
    NSError *error;
    //注意改变设备属性前一定要首先调用lockForConfiguration:调用完之后使用unlockForConfiguration方法解锁
    if ([captureDevice lockForConfiguration:&error]) {
        //自动白平衡
        if ([captureDevice isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
            [captureDevice setWhiteBalanceMode:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance];
        }
        //自动根据环境条件开启闪光灯
        if ([captureDevice isFlashModeSupported:AVCaptureFlashModeAuto]) {
            [captureDevice setFlashMode:AVCaptureFlashModeAuto];
        }
        
        propertyChange(captureDevice);
        [captureDevice unlockForConfiguration];
    }else{
        NSLog(@"设置设备属性过程发生错误，错误信息：%@",error.localizedDescription);
    }
}

//取得指定位置的摄像头
-(AVCaptureDevice *)getCameraDeviceWithPosition:(AVCaptureDevicePosition )position{
    NSArray *cameras= [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *camera in cameras) {
        if ([camera position] == position) {
            return camera;
        }
    }
    return nil;
}
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - 视频输出代理
-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections{
    NSLog(@"开始录制...");
    self.seconds = self.HSeconds;
    [self performSelector:@selector(onStartTranscribe:) withObject:fileURL afterDelay:1.0];
}
- (void)onStartTranscribe:(NSURL *)fileURL {
    if ([self.captureMovieFileOutput isRecording]) {
        -- self.seconds;
        if (self.seconds > 0) {
            if (self.HSeconds - self.seconds >= TimeMax && !self.isVideo) {
                self.isVideo = YES;//长按时间超过TimeMax 表示是视频录制
                self.progressView.timeMax = self.seconds;
            }
            [self performSelector:@selector(onStartTranscribe:) withObject:fileURL afterDelay:1.0];
        } else {
            if ([self.captureMovieFileOutput isRecording]) {
                [self.captureMovieFileOutput stopRecording];
            }
        }
    }
}

-(void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error{
    NSLog(@"视频录制完成.");
    if (self.isVideo) {
        [self changeLayout];
        self.saveVideoUrl = outputFileURL;
        if (!self.player) {
            self.player = [[MLAVPlayer alloc] initWithFrame:self.bgView.bounds withShowInView:self.bgView url:outputFileURL];
            [self.bgView bringSubviewToFront:self.btnAfresh];
            [self.bgView bringSubviewToFront:self.btnEnsure];
        } else {
            if (outputFileURL) {
                self.player.videoUrl = outputFileURL;
                self.player.hidden = NO;
            }
        }
    } else {
        //提示录制时间太短
        return;
    }
    
}
//拍摄完成时调用
- (void)changeLayout {
    self.imgRecord.hidden = YES;
    self.btnCamera.hidden = YES;
    self.btnAfresh.hidden = NO;
    self.btnEnsure.hidden = NO;
    self.btnBack.hidden = YES;
    if (self.isVideo) {
        [self.progressView clearProgress];
    }
    [UIView animateWithDuration:0.8 animations:^{
        [self.btnAfresh mas_updateConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.view.mas_centerX).with.offset(-120);
        }];
        [self.btnEnsure mas_updateConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.view.mas_centerX).with.offset(120);
        }];
    }];
    
    self.lastBackgroundTaskIdentifier = self.backgroundTaskIdentifier;
    self.backgroundTaskIdentifier = UIBackgroundTaskInvalid;
    [self.session stopRunning];
}


//获取第几秒 里的第几帧图片
- (UIImage *)videoHandlePhoto:(NSURL *)url {
    AVURLAsset *urlSet = [AVURLAsset assetWithURL:url];
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:urlSet];
    imageGenerator.appliesPreferredTrackTransform = YES;    // 截图的时候调整到正确的方向
    NSError *error = nil;
    CMTime time = CMTimeMake(2,2);//缩略图创建时间 CMTime是表示电影时间信息的结构体，第一个参数表示是视频第几秒，第二个参数表示每秒帧数.(如果要获取某一秒的第几帧可以使用CMTimeMake方法)
    CMTime actucalTime; //缩略图实际生成的时间
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:time actualTime:&actucalTime error:&error];
    if (error) {
        NSLog(@"截取视频图片失败:%@",error.localizedDescription);
    }
    CMTimeShow(actucalTime);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    
    CGImageRelease(cgImage);
    if (image) {
        NSLog(@"视频截取成功");
    } else {
        NSLog(@"视频截取失败");
    }
    return image;
}

#pragma mark - 通知

//注册通知
- (void)setupObservers
{
    NSNotificationCenter *notification = [NSNotificationCenter defaultCenter];
    [notification addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationWillResignActiveNotification object:[UIApplication sharedApplication]];
}
-(void)removeNotificationFromCaptureDevice:(AVCaptureDevice *)captureDevice{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:captureDevice];
}
//进入后台就退出视频录制
- (void)applicationDidEnterBackground:(NSNotification *)notification {
    [self dq_back];
}

#pragma mark - 界面交互
//点击返回上个页面
- (void)dq_back{
    [self dismissViewControllerAnimated:YES completion:^{
    }];
}
//点击重新录制
- (void)dq_fresh:(UIButton *)btn{
    [self recoverLayout];
}
//切换前后摄像头
-(void)dq_changeCamera:(UIButton *)sender{
    AVCaptureDevice *currentDevice=[self.captureDeviceInput device];
    AVCaptureDevicePosition currentPosition=[currentDevice position];
    [self removeNotificationFromCaptureDevice:currentDevice];
    AVCaptureDevice *toChangeDevice;
    AVCaptureDevicePosition toChangePosition = AVCaptureDevicePositionFront;//前
    if (currentPosition == AVCaptureDevicePositionUnspecified || currentPosition == AVCaptureDevicePositionFront) {
        toChangePosition = AVCaptureDevicePositionBack;//后
    }
    toChangeDevice=[self getCameraDeviceWithPosition:toChangePosition];
    [self addNotificationToCaptureDevice:toChangeDevice];
    //获得要调整的设备输入对象
    AVCaptureDeviceInput *toChangeDeviceInput=[[AVCaptureDeviceInput alloc]initWithDevice:toChangeDevice error:nil];
    //改变会话的配置前一定要先开启配置，配置完成后提交配置改变
    [self.session beginConfiguration];
    [self.session removeInput:self.captureDeviceInput]; //移除原有输入对象
    if ([self.session canAddInput:toChangeDeviceInput]) {//添加新的输入对象
        [self.session addInput:toChangeDeviceInput];
        self.captureDeviceInput = toChangeDeviceInput;
    }
    [self.session commitConfiguration];//提交会话配置
}
//点击确认按钮，保存相册到本地相册，并且回传给上个页面
- (void)dq_ensure:(UIButton *)btn{
    if (self.saveVideoUrl) {
        __weak typeof (self) weakSelf = self;
//        [Utility showProgressDialogText:@"视频处理中..."];
        ALAssetsLibrary *assetsLibrary=[[ALAssetsLibrary alloc]init];
        [assetsLibrary writeVideoAtPathToSavedPhotosAlbum:self.saveVideoUrl completionBlock:^(NSURL *assetURL, NSError *error) {
            NSLog(@"outputUrl:%@",weakSelf.saveVideoUrl);
            [[NSFileManager defaultManager] removeItemAtURL:weakSelf.saveVideoUrl error:nil];
            if (weakSelf.lastBackgroundTaskIdentifier!= UIBackgroundTaskInvalid) {
                [[UIApplication sharedApplication] endBackgroundTask:weakSelf.lastBackgroundTaskIdentifier];
            }
            if (error) {
                NSLog(@"保存视频到相簿过程中发生错误，错误信息：%@",error.localizedDescription);
            } else {
                if (weakSelf.takeBlock) {
                    weakSelf.takeBlock(assetURL,[self videoHandlePhoto:assetURL]);
                }
                NSLog(@"成功保存视频到相簿.");
                NSLog(@"%@",[self videoHandlePhoto:assetURL]);
                [weakSelf dq_back];
            }
        }];
    } else {
        [self dq_back];
    }
}

//重新拍摄时调用
- (void)recoverLayout {
    if (self.isVideo) {
        self.isVideo = NO;
        [self.player stopPlayer];
        self.player.hidden = YES;
    }
    [self.session startRunning];
    self.imgRecord.hidden = NO;
    self.btnCamera.hidden = NO;
    self.btnAfresh.hidden = YES;
    self.btnEnsure.hidden = YES;
    self.btnBack.hidden = NO;
    [UIView animateWithDuration:0.8 animations:^{
        [self.btnAfresh mas_updateConstraints:^(MASConstraintMaker *make) {
             make.centerX.equalTo(self.view);
        }];
        [self.btnEnsure mas_updateConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.view);
        }];
    }];
}
/**
 *  移除所有通知
 */
-(void)removeNotification{
    NSNotificationCenter *notificationCenter= [NSNotificationCenter defaultCenter];
    [notificationCenter removeObserver:self];
}

- (void)dq_layoutSubViews{
    [self.btnAfresh mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.centerY.equalTo(self.view.mas_bottom).with.offset(-100);
        make.size.mas_equalTo(CGSizeMake(60, 60));
    }];
    [self.btnEnsure mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.centerY.equalTo(self.view.mas_bottom).with.offset(-100);
        make.size.mas_equalTo(CGSizeMake(60, 60));
    }];
    [self.btnCamera mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_top).with.offset(40);
        make.right.equalTo(self.view.mas_right).with.offset(-30);
        make.size.mas_equalTo(CGSizeMake(37, 37));
    }];
    [self.btnBack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_top).with.offset(40);
        make.left.equalTo(self.view.mas_left).with.offset(30);
        make.size.mas_equalTo(CGSizeMake(40, 40));
    }];
    [self.imgRecord mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.centerY.equalTo(self.view.mas_bottom).with.offset(-100);
        make.size.mas_equalTo(CGSizeMake(90, 90));
    }];
    [self.progressView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self.imgRecord);
        make.size.mas_equalTo(CGSizeMake(90, 90));
    }];
    [self.labelTipTitle mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.imgRecord);
        make.bottom.equalTo(self.imgRecord.mas_top).with.offset(-20);
    }];
    self.progressView.layer.cornerRadius = self.progressView.frame.size.width/2;
    if (self.HSeconds == 0) {
        self.HSeconds = 10; //重复播放
    }
}
#pragma mark - set
-(UIImageView *)bgView{
    if (!_bgView) {
        _bgView = [[UIImageView alloc]init];
        _bgView.userInteractionEnabled = YES;
        _bgView.frame = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT);
        [self.view addSubview:_bgView];
    }
    return _bgView;
}
-(UIButton *)btnAfresh{
    if (!_btnAfresh) {
        _btnAfresh = [[UIButton alloc]init];
        [_btnAfresh setImage:[UIImage imageNamed:@"shortVideo_refresh"] forState:UIControlStateNormal];
        _btnAfresh.hidden = YES;
        [_btnAfresh addTarget:self action:@selector(dq_fresh:) forControlEvents:UIControlEventTouchUpInside];
        [self.bgView addSubview:_btnAfresh];
    }
    return _btnAfresh;
}
-(UIButton *)btnEnsure{
    if (!_btnEnsure) {
        _btnEnsure = [[UIButton alloc]init];
        [_btnEnsure setImage:[UIImage imageNamed:@"shortVideo_submit"] forState:UIControlStateNormal];
        _btnEnsure.hidden = YES;
        [_btnEnsure addTarget:self action:@selector(dq_ensure:) forControlEvents:UIControlEventTouchUpInside];
        [self.bgView addSubview:_btnEnsure];
    }
    return _btnEnsure;
}
-(UIButton *)btnCamera{
    if (!_btnCamera) {
        _btnCamera = [[UIButton alloc]init];
        [_btnCamera setImage:[UIImage imageNamed:@"btn_video_flip_camera"] forState:UIControlStateNormal];
        [_btnCamera addTarget:self action:@selector(dq_changeCamera:) forControlEvents:UIControlEventTouchUpInside];
        [self.bgView addSubview:_btnCamera];
        
    }
    return _btnCamera;
}
-(UIButton *)btnBack{
    if (!_btnBack) {
        _btnBack = [[UIButton alloc]init];
        [_btnBack setImage:[UIImage imageNamed:@"SX_back"] forState:UIControlStateNormal];
        [_btnBack addTarget:self action:@selector(dq_back) forControlEvents:UIControlEventTouchUpInside];
        [self.bgView addSubview:_btnBack];
    }
    return _btnBack;
}
-(MLProgressView *)progressView{
    if (!_progressView) {
        _progressView = [[MLProgressView alloc]init];
        _progressView.userInteractionEnabled = NO;
        _progressView.backgroundColor = [UIColor clearColor];
        [self.bgView addSubview:_progressView];
    }
    return _progressView;
}
-(UIImageView *)imgRecord{
    if (!_imgRecord) {
        _imgRecord = [[UIImageView alloc]init];
        _imgRecord.userInteractionEnabled = YES;
        _imgRecord.image = [UIImage imageNamed:@"SX_photograph"];
        [self.bgView addSubview:_imgRecord];
    }
    return _imgRecord;
}
-(UILabel *)labelTipTitle{
    if (!_labelTipTitle) {
        _labelTipTitle = [[UILabel alloc]init];
        _labelTipTitle.text = @"长按拍摄小视频";
        _labelTipTitle.textColor = [UIColor whiteColor];
        _labelTipTitle.font = [UIFont systemFontOfSize:14];
        [self.bgView addSubview:_labelTipTitle];
    }
    return _labelTipTitle;
}
@end
