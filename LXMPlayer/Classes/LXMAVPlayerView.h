//
//  LXMAVPlayerManager.h
//  LXMPlayer
//
//  Created by luxiaoming on 2018/8/28.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSInteger, LXMAVPlayerContentMode) {
    LXMAVPlayerContentModeScaleAspectFit = 0,    //AVLayerVideoGravityResizeAspect;
    LXMAVPlayerContentModeScaleAspectFill = 1,   //AVLayerVideoGravityResizeAspectFill;
    LXMAVPlayerContentModeScaleToFill = 2,       //AVLayerVideoGravityResize;
};




NS_ASSUME_NONNULL_BEGIN

@interface  LXMAVPlayerView : UIView


@end

NS_ASSUME_NONNULL_END
