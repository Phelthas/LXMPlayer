//
//  LXMViewController.m
//  LXMPlayer
//
//  Created by billthas@gmail.com on 08/28/2018.
//  Copyright (c) 2018 billthas@gmail.com. All rights reserved.
//

#import "LXMViewController.h"
#import <LXMPlayer/LXMPlayer.h>

@interface LXMViewController ()

@property (nonatomic, strong) LXMAVPlayerView *playerView;

@end

@implementation LXMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    CGRect bounds = [[UIScreen mainScreen] bounds];
    LXMAVPlayerView *testView = [[LXMAVPlayerView alloc] initWithFrame:CGRectMake(0, 44, bounds.size.width, bounds.size.width / 16 * 9)];
    
//    [testView setPlayerTimeDidChangeBlock:^(NSTimeInterval currentTime, NSTimeInterval totalTime) {
//        NSLog(@"PlayerTimeDidChangeBlock: %@, %@", @(currentTime), @(totalTime));
//    }];
    
    [testView setPlayerStatusDidChangeBlock:^(LXMAVPlayerStatus status) {
        NSLog(@"PlayerStatusDidChangeBlock: %@", @(status));
    }];
    
    [testView setPlayerDidPlayToEndBlock:^(AVPlayerItem *item) {
        NSLog(@"PlayerDidPlayToEndBlock");
    }];
    
    
    
    self.playerView = testView;
    testView.backgroundColor = UIColor.orangeColor;
    [self.view addSubview:testView];
    
    
    NSLog(@"%@",testView);
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Action

- (IBAction)handlePlayButtonTapped:(id)sender {
    NSString *testUrl = @"https://media.w3.org/2010/05/sintel/trailer.mp4";
    NSURL *url = [NSURL URLWithString:testUrl];
    self.playerView.assetURL = url;
    [self.playerView play];
}

- (IBAction)handlePauseButtonTapped:(id)sender {
    [self.playerView pause];
}


@end
