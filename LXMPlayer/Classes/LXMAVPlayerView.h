//
//  LXMAVPlayerView.h
//  LXMPlayer
//
//  Created by luxiaoming on 2018/8/28.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, LXMAVPlayerContentMode) {
    LXMAVPlayerContentModeScaleAspectFit = 0,    //AVLayerVideoGravityResizeAspect;
    LXMAVPlayerContentModeScaleAspectFill = 1,   //AVLayerVideoGravityResizeAspectFill;
    LXMAVPlayerContentModeScaleToFill = 2,       //AVLayerVideoGravityResize;
};


typedef NS_ENUM(NSInteger, LXMAVPlayerStatus) {
    LXMAVPlayerStatusUnknown = 0,
    LXMAVPlayerStatusStalling,
    LXMAVPlayerStatusReadyToPlay,
    LXMAVPlayerStatusPlaying,
    LXMAVPlayerStatusPaused,
    LXMAVPlayerStatusFailed,
    LXMAVPlayerStatusStoped,
};


typedef void(^LXMAVPlayerTimeDidChangeBlock)(NSTimeInterval currentTime, NSTimeInterval totalTime);
typedef void(^LXMAVPlayerDidPlayToEndBlock)(AVPlayerItem *item);
typedef void(^LXMAVPlayerStatusDidChangeBlock)(LXMAVPlayerStatus status);

@interface  LXMAVPlayerView : UIView

@property (nonatomic, strong, nullable) NSURL *assetURL;
@property (nonatomic, copy) AVLayerVideoGravity videoGravity;

//time
@property (nonatomic, assign, readonly) NSTimeInterval currentTime;
@property (nonatomic, assign, readonly) NSTimeInterval totalTime;
@property (nonatomic, assign, readonly) LXMAVPlayerStatus playerStatus;


//callback
@property (nonatomic, copy, nullable) LXMAVPlayerTimeDidChangeBlock playerTimeDidChangeBlock;
@property (nonatomic, copy, nullable) LXMAVPlayerDidPlayToEndBlock playerDidPlayToEndBlock;
@property (nonatomic, copy, nullable) LXMAVPlayerStatusDidChangeBlock playerStatusDidChangeBlock;


#pragma mark - PublicMethod

- (void)play;

- (void)pause;

- (void)stop;

- (void)reset;

- (void)replay;

- (nullable UIImage *)thumbnailAtCurrentTime;


@end
