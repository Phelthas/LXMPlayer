//
//  LXMAVPlayerView.m
//  LXMPlayer
//
//  Created by luxiaoming on 2018/8/28.
//

#import "LXMAVPlayerView.h"
#import <KVOController/KVOController.h>
#import <LXMPlayer/LXMPlayerMacro.h>
#import <LXMBlockKit/LXMBlockKit.h>
#import "LXMPlayerMacro.h"


//static void * kLXMAVPlayerViewContext = &kLXMAVPlayerViewContext;
static NSString * const kAVPlayerItemStatus = @"status";
static NSString * const kAVPlayerItemPlaybackBufferEmpty = @"playbackBufferEmpty";
static NSString * const kAVPlayerItemPlaybackLikelyToKeepUp = @"playbackLikelyToKeepUp";

@interface  LXMAVPlayerView ()

//private

@property (nonatomic, strong) AVURLAsset *urlAsset;
@property (nonatomic, strong) AVPlayer *avPlayer;
@property (nonatomic, strong, readonly) AVPlayerLayer *playerLayer;
@property (nonatomic, strong) id timeObserver;
@property (nonatomic, assign) BOOL isPlayerInited;
@property (nonatomic, assign) BOOL isRepeatPlay; // 是否在startSeconds和endSeconds之间重复播放

@property (nonatomic, assign, readwrite) LXMAVPlayerStatus playerStatus;


@property (nonatomic, assign) LXMAVPlayerStatus statusBeforeBackground;

@end


@implementation  LXMAVPlayerView


/**
 这里这么写是为了让这个view本身的layer成为AVPlayerLayer，这样的话系统会自动根据view的大小来调整layer
 */
+ (Class)layerClass {
    return [AVPlayerLayer class];
}

- (AVPlayerLayer *)playerLayer {
    return (AVPlayerLayer *)self.layer;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor blackColor];
        self.playerLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        self.volume = 1.0;
    }
    return self;
}



#pragma mark -


- (void)initializePlayer {
    
    if (_assetURL != nil) {
        self.urlAsset = [AVURLAsset assetWithURL:self.assetURL];
        self.playerItem = [AVPlayerItem playerItemWithAsset:self.urlAsset];
    } else if (_playerItem != nil){
        _urlAsset = _playerItem.asset;
    }
    self.avPlayer = [AVPlayer playerWithPlayerItem:self.playerItem];
    self.avPlayer.volume = self.volume;
    self.avPlayer.actionAtItemEnd = AVPlayerActionAtItemEndPause;
    self.playerLayer.player = self.avPlayer;
    self.playerLayer.videoGravity = self.videoGravity;
    if (@available(iOS 9.0, *)) {
        self.playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = NO;
    }
    if (@available(iOS 10.0, *)) {
        self.avPlayer.automaticallyWaitsToMinimizeStalling = NO;
    }
    [self addItemObserver];
}

- (void)addItemObserver {
    /*
     1)打断点观察，当调用play方法的时候，首先会观察到kAVPlayerRate的变化，从0变到1;但这时候并没有画面，因为还没有任何数据；
     2)然后开始loading，稍后就会观察到kAVPlayerItemPlaybackBufferEmpty的变化，从1变为0，说有缓存到内容了，已经有loadedTimeRanges了，但这时候还不一定能播放，因为数据可能还不够播放；
     3)然后是kAVPlayerItemPlaybackLikelyToKeepUp的变化，新旧值都是0，这时候还没什么用，因为本来就还没开始播放；
     4)然后是kAVPlayerItemStatus的变化，从0变为1，即变为readyToPlay
     5)然后是kAVPlayerItemPlaybackLikelyToKeepUp，从0变到1，说明可以播放了，这时候会自动开始播放
     */
    
    /*
     当播放本地视频时KVO观察到的顺序与播放网络视频时不太一样：
     1，首先是观察到kAVPlayerItemPlaybackBufferEmpty的变化，从1变为0，说有缓存到内容了，已经有loadedTimeRanges了，但这时候还不一定能播放，因为数据可能还不够播放；
     2，然后是kAVPlayerItemPlaybackLikelyToKeepUp，从0变到1，说明可以播放了，这时候会自动开始播放
     3，然后是kAVPlayerItemStatus的变化，从0变为1，即变为readyToPlay
     即不同于网络播放的场景，播放本地视频时，是先观察到playing开始，kAVPlayerItemStatus才变为readyToPlay的。
     */
    
    /*
     所以player的rate是没有必要观察的，rate就是在player调用play的时候变为1，调用pause的时候变为0，它的值不根据卡不卡变化，
     它应该是用来决定当load到新数据是要不要继续播放。
     文档上还提到一种情况，playbackBufferFull是true但是isPlaybackLikelyToKeepUp还是false，即缓存已经满了，但是缓存的这些内容还不够用来播放，这种情况要自己处理。。。这种情况应该不多，我这儿没有处理。。。
     */
    
    @weakify(self)
    
    [self.KVOController observe:self.playerItem keyPath:kAVPlayerItemStatus options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld block:^(id  _Nullable observer, AVPlayerItem * _Nullable object, NSDictionary<NSString *,id> * _Nonnull change) {
        //        NSLog(@"change: %@", change);
        @strongify(self)
        /*
         测试的时候发现，在真机上，APP从后台返回前台，会观察到playerItem的status变化，但新旧值都是readToPlay,模拟器上没有这个问题。。。
         */
        AVPlayerItemStatus oldStatus = (AVPlayerItemStatus)[change[NSKeyValueChangeOldKey] integerValue];
        AVPlayerItemStatus newStatus = (AVPlayerItemStatus)[change[NSKeyValueChangeNewKey] integerValue];
        if (oldStatus == newStatus) {
            return;
        }
        switch (newStatus) {
            case AVPlayerItemStatusReadyToPlay:
            {
                // 如果有设置开始时间，则快进到开始时间点
                if (self.startSeconds > 0) {
                    CMTime start = CMTimeMakeWithSeconds(self.startSeconds, [self currentTimeScale]);
                    [self seekToTimeAndPlay:start];
                }
                
                if (self.playerItemReadyToPlayBlock) {
                    self.playerItemReadyToPlayBlock();
                }
            }
                break;
            case AVPlayerItemStatusFailed:
                if (self.playerStatusDidChangeBlock) {
                    self.playerStatusDidChangeBlock(LXMAVPlayerStatusFailed);
                }
            case AVPlayerItemStatusUnknown:
                if (self.playerStatusDidChangeBlock) {
                    self.playerStatusDidChangeBlock(LXMAVPlayerStatusUnknown);
                }
                break;
        }
    }];
    
    [self.KVOController observe:self.playerItem keyPath:kAVPlayerItemPlaybackBufferEmpty options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        //        NSLog(@"change: %@", change);
        @strongify(self)
        if (self.playerStatus == LXMAVPlayerStatusPaused) {
            // 这里这么写是因为：状态变化是异步的，有可能在播放器暂停时观察到状态变化，这时候不应该变动原来的状态
            return;
        }
        BOOL oldValue = [change[NSKeyValueChangeOldKey] boolValue];
        BOOL newValue = [change[NSKeyValueChangeNewKey] boolValue];
        if (oldValue == NO && newValue == YES) {
            //这里这么写是因为观察到会有old new都是0的情况
            self.playerStatus = LXMAVPlayerStatusStalling;
            [self delegateStatusDidChangeBlock];
        }
    }];
    
    [self.KVOController observe:self.playerItem keyPath:kAVPlayerItemPlaybackLikelyToKeepUp options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        //        NSLog(@"change: %@", change);
        @strongify(self)
        if (self.playerStatus == LXMAVPlayerStatusPaused) {
            // 这里这么写是因为：状态变化是异步的，有可能在播放器暂停时观察到状态变化，这时候不应该变动原来的状态
            return;
        }
        BOOL oldValue = [change[NSKeyValueChangeOldKey] boolValue];
        BOOL newValue = [change[NSKeyValueChangeNewKey] boolValue];
        if (oldValue == NO && newValue == YES) { //这里这么写是因为观察到会有old new都是0的情况
            self.playerStatus = LXMAVPlayerStatusPlaying;
            [self delegateStatusDidChangeBlock];
        }
        
    }];
    
    
    CMTime interval = CMTimeMakeWithSeconds(1, [self currentTimeScale]);
    if (_playTimeUpdateRate.timescale > 0 && _playTimeUpdateRate.value > 0) {
        interval = _playTimeUpdateRate;
    }
    self.timeObserver = [self.avPlayer addPeriodicTimeObserverForInterval:interval queue:dispatch_get_main_queue() usingBlock:^(CMTime time) {
        @strongify(self)
        if (self.totalSeconds == 0) {
            return;
        }
        
        if (self.playerStatus == LXMAVPlayerStatusPaused || self.playerStatus == LXMAVPlayerStatusStopped) {
            return;
        }
        
        if (self.endSeconds > 0) {
            NSTimeInterval seconds = CMTimeGetSeconds(time);
            NSTimeInterval delta = fabs(self.endSeconds - seconds);
            if ((delta < 0.01) || (seconds > self.endSeconds)){
                // 在 0.01 的误差范围内或者已经超过了目标结束时间，认为达到目标时间点
                CMTime startTime = CMTimeMakeWithSeconds(self.startSeconds, 600);
                
                if (self.isRepeatPlay) {
                    [self seekToTimeWhilePlaying:startTime completion:^(BOOL finished) {
                        //
                    }];
                    
                    if (self.playerSeekToStartTimeBlock) {
                        self.playerSeekToStartTimeBlock();
                    }
                } else {
                    [self pause];
                }
            }
        }
        
        if (self.playerTimeDidChangeBlock) {
            self.playerTimeDidChangeBlock(self.currentSeconds, self.totalSeconds);
        }
        
    }];
    
    [self removeNotificatiions];
    
    [kNSNotificationCenter addObserver:self name:AVPlayerItemDidPlayToEndTimeNotification callback:^(NSNotification * _Nullable sender) {
        @strongify(self)
        if (sender.object == self.avPlayer.currentItem) {
            if (self.playerDidPlayToEndBlock) {
                self.playerDidPlayToEndBlock(sender.object);
            }
            self.playerStatus = LXMAVPlayerStatusStopped;
            [self delegateStatusDidChangeBlock];
        }
    }];
    
    [kNSNotificationCenter addObserver:self name:UIApplicationWillResignActiveNotification callback:^(NSNotification * _Nullable sender) {
        @strongify(self)
        // 加这个判断是因为貌似，这个通知在拉下通知栏的时候会触发两次
        if (self.statusBeforeBackground == LXMAVPlayerStatusUnknown) {
            self.statusBeforeBackground = self.playerStatus;
            [self pause];
        }
        
    }];
    
    [kNSNotificationCenter addObserver:self name:UIApplicationDidBecomeActiveNotification callback:^(NSNotification * _Nullable sender) {
        @strongify(self)
        if (self.statusBeforeBackground == LXMAVPlayerStatusUnknown) {
            return;
        }
        if (self.statusBeforeBackground == LXMAVPlayerStatusPlaying ||
            self.statusBeforeBackground == LXMAVPlayerStatusStalling) {
            [self play];
        }
        self.statusBeforeBackground = LXMAVPlayerStatusUnknown;
    }];
    
}

- (void)removeNotificatiions {
    [kNSNotificationCenter lxm_removeObserver:self name:AVPlayerItemDidPlayToEndTimeNotification object:nil];
    [kNSNotificationCenter lxm_removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [kNSNotificationCenter lxm_removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)delegateStatusDidChangeBlock {
    if (self.playerStatusDidChangeBlock) {
        self.playerStatusDidChangeBlock(self.playerStatus);
    }
}




#pragma mark - PublicMethod

- (void)play {
    if (nil == self.assetURL && nil == self.playerItem) {
        return;
    }
    if (self.playerStatus == LXMAVPlayerStatusPlaying) {
        return;
    }
    if (self.isPlayerInited == NO) {
        [self initializePlayer];
        self.isPlayerInited = YES;
    }
    
    // 达到了设定的结束时间，这个结束时间可能小于视频的实际结束时间
    if (self.endSeconds > 0) {
        NSTimeInterval delta = fabs(self.endSeconds - self.currentSeconds);
        if ((delta < 0.01) || (self.currentSeconds > self.endSeconds)){
            [self seekToStartTimeAndPlay];
        } else {
            [self.avPlayer play];
        }
    } else {
        [self.avPlayer play];
    }
    
    if (self.playerStatus != LXMAVPlayerStatusPlaying) {
        self.playerStatus = LXMAVPlayerStatusPlaying;
        [self delegateStatusDidChangeBlock];
    }
    
}

- (void)pause {
    [self.avPlayer pause];
    if (self.playerStatus != LXMAVPlayerStatusPaused) {
        self.playerStatus = LXMAVPlayerStatusPaused;
        [self delegateStatusDidChangeBlock];
    }
    
}

- (void)stop {
    [self.avPlayer seekToTime:kCMTimeZero];
    [self.avPlayer pause];
    [self.avPlayer cancelPendingPrerolls];
    if (self.playerStatus != LXMAVPlayerStatusStopped) {
        self.playerStatus = LXMAVPlayerStatusStopped;
        [self delegateStatusDidChangeBlock];
    }
}



- (void)reset {
    [self.avPlayer pause];
    [self.avPlayer cancelPendingPrerolls];
    [self.KVOController unobserveAll];
    if (self.timeObserver) {
        [self.avPlayer removeTimeObserver:self.timeObserver];
        self.timeObserver = nil;
    }
    [self removeNotificatiions];
    
    self.playerLayer.player = nil; //千万注意这一句，坑了我好久，AVPlayerLayer会retain它的player，如果这里不主动设置为nil，player就不会释放。
    _assetURL = nil; //使用点语法会触发set方法，所以这里直接访问实例变量了
    self.urlAsset = nil;
    self.playerItem = nil;
    self.avPlayer = nil;
    self.isPlayerInited = NO;
    if (self.playerStatus != LXMAVPlayerStatusUnknown) {
        self.playerStatus = LXMAVPlayerStatusUnknown;
        [self delegateStatusDidChangeBlock];
    }
    
}

- (void)replay {
    
    if (self.startSeconds > 0) {
        [self seekToStartTimeAndPlay];
        return;
    }
    
    [self seekToTimeAndPlay:kCMTimeZero];
}

- (void)seekToTimeAndPlay:(CMTime)time {
    [self seekToTime:time completion:nil];
}

- (void)seekToStartTimeAndPlay {
    
    CMTime startTime = CMTimeMakeWithSeconds(self.startSeconds, [self currentTimeScale]);
    if (self.isPlayerInited == NO) {
        // 如果没有初始化，等初始化完并准备播放时，监听到AVPlayerItemStatusReadyToPlay再seek到目标开始时间
        [self play];
    } else {
        [self seekToTime:startTime completion:nil];
    }
    
    if (self.playerSeekToStartTimeBlock) {
        self.playerSeekToStartTimeBlock();
    }
}

- (void)seekToTime:(CMTime)time completion:(void (^)(BOOL finished))completion {
    [self seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completion:completion];
}

- (void)seekToTime:(CMTime)time toleranceBefore:(CMTime)toleranceBefore toleranceAfter:(CMTime)toleranceAfter completion:(void (^)(BOOL finished))completion {
    if (self.isReadyToPlay == NO) { return; }
    if (self.playerItem == nil) {
        return;
    }
    if (self.endSeconds > 0) {
        // 如果限制了播放结束时间，那么seek时间点超过限制结束时间点时需要跳过
        NSTimeInterval seekTimeSeconds = CMTimeGetSeconds(time);
        if (seekTimeSeconds > self.endSeconds) {
            return;
        }
    }
    
    //友盟统计到一个Seeking is not possible to time {INDEFINITE}的bug，这么修复一下
    if (CMTIME_IS_INDEFINITE(time) || CMTIME_IS_INVALID(time)) {
        return;
    }
    [self.avPlayer pause];//seek之前还是应该暂停住，且不应该让外界感知到；因为如果在刚readToPlay就seek的话，如果不暂停，会让视频第一帧先放出来，造成界面闪一下。（因为seek的回调是异步的，应该在seek完成的回调中再开始播放）
    
    @weakify(self)
    [self.avPlayer seekToTime:time toleranceBefore:toleranceBefore toleranceAfter:toleranceAfter completionHandler:^(BOOL finished) {
        @strongify(self)
        [self.avPlayer play];//这里直接播放还是不行的，如果连续拖动调用的话可能会导致暂停跟播放顺序混乱，为了兼容之前的版本，先不该这里，改用下面的seekToTimeWhilePlaying方法，等有空一起改
        
        // 这是是发现当stop以后，seek到前面开始播放player状态不会恢复，所以这么处理下
        if (self.playerStatus == LXMAVPlayerStatusStopped || self.playerStatus == LXMAVPlayerStatusPaused) {
            self.playerStatus = LXMAVPlayerStatusPlaying;
            [self delegateStatusDidChangeBlock];
        }
        
        if (self.seekTimeCompleteBlock) {
            self.seekTimeCompleteBlock(CMTimeGetSeconds(time), self.totalSeconds);
        }
        
        // 等上面通知完状态变更后才回调，不然如果回调里面暂停视频会出现状态不同步的情况
        if (completion) {
            completion(finished);
        }
    }];
}

- (void)seekToTimeWhilePlaying:(CMTime)time completion:(void (^)(BOOL finished))completion {
    if (self.isReadyToPlay == NO) { return; }
    if (self.playerItem == nil) {
        return;
    }
    if (self.endSeconds > 0) {
        // 如果限制了播放结束时间，那么seek时间点超过限制结束时间点时需要跳过
        NSTimeInterval seekTimeSeconds = CMTimeGetSeconds(time);
        if (seekTimeSeconds > self.endSeconds) {
            return;
        }
    }
    //友盟统计到一个Seeking is not possible to time {INDEFINITE}的bug，这么修复一下
    if (CMTIME_IS_INDEFINITE(time) || CMTIME_IS_INVALID(time)) {
        return;
    }
    
    @weakify(self)
    [self.avPlayer seekToTime:time toleranceBefore:kCMTimeZero toleranceAfter:kCMTimeZero completionHandler:^(BOOL finished) {
        
        if (self.seekTimeCompleteBlock) {
            self.seekTimeCompleteBlock(CMTimeGetSeconds(time), self.totalSeconds);
        }
        
        if (completion) {
            completion(finished);
        }
    }];
}


- (nullable UIImage *)thumbnailAtCurrentTime {
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:self.urlAsset];
    CMTime expectedTime = self.playerItem.currentTime;
    CGImageRef cgImage = NULL;
    imageGenerator.requestedTimeToleranceBefore = kCMTimeZero;
    imageGenerator.requestedTimeToleranceAfter = kCMTimeZero;
    cgImage = [imageGenerator copyCGImageAtTime:expectedTime actualTime:NULL error:NULL];
    if (!cgImage) {
        imageGenerator.requestedTimeToleranceBefore = kCMTimePositiveInfinity;
        imageGenerator.requestedTimeToleranceAfter = kCMTimePositiveInfinity;
        cgImage = [imageGenerator copyCGImageAtTime:expectedTime actualTime:NULL error:NULL];
    }
    return [UIImage imageWithCGImage:cgImage];
}

- (void)replaceCurrentPlayerItemWithPlayerItem:(nullable AVPlayerItem *)playerItem {
    self.assetURL = nil;
    self.playerItem = playerItem;
    [self.avPlayer replaceCurrentItemWithPlayerItem:playerItem];
    if (self.playerStatus == LXMAVPlayerStatusPlaying) {
        [self.avPlayer play];
    }
    if (@available(iOS 9.0, *)) {
        self.playerItem.canUseNetworkResourcesForLiveStreamingWhilePaused = NO;
    }
}

- (void)changePlayTimeRangeWithStart:(NSTimeInterval)start end:(NSTimeInterval)end isRepeat:(BOOL)isRepeat{
    self.startSeconds = start;
    self.endSeconds = end;
    self.isRepeatPlay = isRepeat;
}


#pragma mark - Property


/**
 注意：设置新的url会重置playerView
 */
- (void)setAssetURL:(NSURL *)assetURL {
    if (assetURL == _assetURL) {
        return;
    }
    if (assetURL != nil) {
        [self reset];
    }
    _assetURL = assetURL;
}

- (void)setPlayerItem:(AVPlayerItem *)playerItem {
    if (playerItem == _playerItem) {
        return;
    }
    if (playerItem != nil) {
        [self reset];
    }
    
    _playerItem = playerItem;
}

- (NSTimeInterval)currentSeconds {
    if (self.playerItem != nil && self.isReadyToPlay) {
        NSTimeInterval time = CMTimeGetSeconds(self.playerItem.currentTime);
        if (isnan(time)) {
            return 0;
        }
        return time;
    }
    return 0;
}

- (NSTimeInterval)totalSeconds {
    if (self.playerItem != nil && self.isReadyToPlay) {
        NSTimeInterval time = CMTimeGetSeconds(self.playerItem.duration);
        if (isnan(time)) {
            return 0;
        }
        return time;
    }
    return 0;
}

- (BOOL)isReadyToPlay {
    if (self.playerItem != nil && self.playerItem.status == AVPlayerItemStatusReadyToPlay) {
        return YES;
    }
    return NO;
}

- (int32_t)currentTimeScale {
    if (self.playerItem) {
        return self.playerItem.duration.timescale;
    } else {
        return 600;
    }
}

- (void)setVolume:(float)volume {
    _volume = volume;
    if (volume > 1.0) {
        _volume = 1.0;
    } else if (volume < 0.0) {
        _volume = 0.0;
    }
    
    self.avPlayer.volume = volume;
}

@end

