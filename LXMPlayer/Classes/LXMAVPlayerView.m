//
//  LXMAVPlayerManager.m
//  LXMPlayer
//
//  Created by luxiaoming on 2018/8/28.
//

#import "LXMAVPlayerView.h"
#import <AVFoundation/AVFoundation.h>
#import <KVOController/KVOController.h>

//static void * kLXMAVPlayerViewContext = &kLXMAVPlayerViewContext;
static NSString * const kAVPlayerItemStatus = @"status";


@interface  LXMAVPlayerView ()

//public
@property (nonatomic, strong) NSURL *assetURL;
@property (nonatomic, copy) AVLayerVideoGravity videoGravity;

//private
@property (nonatomic, strong) AVPlayer *avPlayer;
@property (nonatomic, strong) AVURLAsset *urlAsset;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVPlayerLayer *playerLayer;


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
    }
    return self;
}



#pragma mark -

- (void)prepareToPlay {
    if (!self.assetURL) {
        return;
    }
    [self initializePlayer];
    
}

- (void)initializePlayer {
    self.urlAsset = [AVURLAsset assetWithURL:self.assetURL];
    self.playerItem = [AVPlayerItem playerItemWithAsset:self.urlAsset];
    self.avPlayer = [AVPlayer playerWithPlayerItem:self.playerItem];
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
    [self.KVOController observe:self.playerItem keyPath:kAVPlayerItemStatus options:NSKeyValueObservingOptionNew block:^(id  _Nullable observer, id  _Nonnull object, NSDictionary<NSString *,id> * _Nonnull change) {
        
    }];
}



@end
