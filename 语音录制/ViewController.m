//
//  ViewController.m
//  语音录制
//
//  Created by wangguigui on 16/3/28.
//  Copyright © 2016年 topsci. All rights reserved.
//

#import "ViewController.h"
#import <CoreAudio/CoreAudioTypes.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()<AVAudioRecorderDelegate,AVAudioPlayerDelegate>

@property (nonatomic, strong) NSURL * recordpath;
@property (nonatomic, strong) AVAudioRecorder * recorder;            //录音
@property (nonatomic, strong) AVAudioPlayer * recordPlayer;          //播放语音

-(IBAction)startRecordClick:(id)sender;
-(IBAction)stopRecordClick:(id)sender;
-(IBAction)playRecordClick:(id)sender;
-(IBAction)stopPlayClick:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

#pragma mark - 开始录音
-(IBAction)startRecordClick:(id)sender
{
    NSMutableDictionary * recordSetting = [NSMutableDictionary dictionary];
    [recordSetting setValue:[NSNumber numberWithInt:kAudioFormatMPEG4AAC] forKey:AVFormatIDKey];
    [recordSetting setValue:[NSNumber numberWithFloat:44110] forKey:AVSampleRateKey];
    [recordSetting setValue:[NSNumber numberWithInt:1] forKey:AVNumberOfChannelsKey];
    
    NSDateFormatter * fm = [[NSDateFormatter alloc]init];
    [fm setDateFormat:@"yyyy-MM-dd-hh-mm-ss"];
    NSDate * date = [NSDate date];
    NSString * dateString = [fm stringFromDate:date];
    NSString * dateStr = [NSString stringWithFormat:@"%@",dateString];
    
    //修改录音路径，判断路径是否存在，如果路径不存在，就要先创建路径然后再录制
    NSString * fileString = [NSString stringWithFormat:@"%@/Library/SaveRecord",NSHomeDirectory()];
    
    if (![[NSFileManager defaultManager]fileExistsAtPath:fileString]) {
        NSError *err = nil;
        if ([[NSFileManager defaultManager] createDirectoryAtPath:fileString withIntermediateDirectories:YES attributes:nil error:&err])
        {
            self.recordpath = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@-wff.aac",fileString,dateStr]];
        } else {
            NSLog(@"路径创建失败");
            return;
        }
    } else {
        self.recordpath = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%@/%@-wff.aac",fileString,dateStr]];
    }
    
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *setCategoryError = nil;
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&setCategoryError];
    
    if(setCategoryError){
        NSLog(@"准备录制时，有错误");
        return;
    }
    
    self.recorder = [[AVAudioRecorder alloc]initWithURL:self.recordpath settings:recordSetting error:nil];
    self.recorder.delegate = self;
    if (_recordPlayer.playing) {
        [_recordPlayer stop];
    }
    [self.recorder record];
    NSLog(@"开始录制");
}

#pragma mark - 停止录音
-(IBAction)stopRecordClick:(id)sender
{
    [self.recorder stop];
    
    //获取录音时长
    AVURLAsset* audioAsset =[AVURLAsset URLAssetWithURL:self.recordpath options:nil];
    CMTime audioDuration = audioAsset.duration;
    float audioDurationSeconds =CMTimeGetSeconds(audioDuration);
    NSLog(@"录音时长为%f",audioDurationSeconds);
}

#pragma mark - 播放录音
-(IBAction)playRecordClick:(id)sender
{
    //在播放前，将语音文件从本地取出来转成data
    NSData *data = [NSData dataWithContentsOfURL:_recordpath];
    _recordPlayer = [[AVAudioPlayer alloc] initWithData:data error:NULL];
    _recordPlayer.delegate = self;
    [_recordPlayer prepareToPlay];

    if (_recordPlayer.playing) {
        [_recordPlayer stop];
    } else {
        [_recordPlayer play];
        
        //如果需要转换听筒和外放播放效果，可以添加下面的方法
        [self addNotificationForPlayer];
    }
}

-(IBAction)stopPlayClick:(id)sender
{
    if (_recordPlayer.playing) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
        [_recordPlayer stop];
    }
}

-(void)addNotificationForPlayer
{
    //这儿的警告是因为系统已经把对应的方法废弃，但是现在还能用，可以忽略
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
    UInt32 audioRouteOverride = kAudioSessionOverrideAudioRoute_Speaker;
    AudioSessionSetProperty (kAudioSessionProperty_OverrideAudioRoute, sizeof (audioRouteOverride), &audioRouteOverride);
    
    //默认情况下扬声器播放
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];
    [audioSession setActive:YES error:nil];
    [self handleNotification:_recordPlayer.playing];
}

#pragma mark - 监听听筒or扬声器
- (void) handleNotification:(BOOL)state
{
    [[UIDevice currentDevice] setProximityMonitoringEnabled:state]; //建议在播放之前设置yes，播放结束设置NO，这个功能是开启红外感应
    if(state) {
        //添加监听
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sensorStateChange:) name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    }else{
        //移除监听
        [[NSNotificationCenter defaultCenter] removeObserver:self name:@"UIDeviceProximityStateDidChangeNotification" object:nil];
    }
}

#pragma mark - 处理监听触发事件
-(void)sensorStateChange:(NSNotificationCenter *)notification;
{
    //如果此时手机靠近面部放在耳朵旁，那么声音将通过听筒输出，并将屏幕变暗
    if ([[UIDevice currentDevice] proximityState] == YES) {
        //Device is close to user
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    } else {
        //Device is not close to user
        [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
