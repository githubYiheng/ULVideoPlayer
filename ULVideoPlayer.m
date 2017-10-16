//
//  ULVideoPlayer.m
//  UpLive
//
//  Created by 王传正 on 13/10/2017.
//  Copyright © 2017 AsiaInnovations. All rights reserved.
//

#import "ULVideoPlayer.h"
#import "ULAVAssetResourceLoader.h"

@interface ULVideoPlayer()

@property (nonatomic, strong) AVPlayer               *player;
@property (nonatomic, strong) AVPlayerItem           *playerItem;
@property (nonatomic, strong) AVURLAsset             *urlAsset;
@property (nonatomic, strong) AVPlayerLayer          *playerLayer;

@property (nonatomic, strong) ULAVAssetResourceLoader *resourceLoader;

@property (nonatomic, assign) BOOL paused;

@end

@implementation ULVideoPlayer

- (void)dealloc{
    _AVPlayerStatusChangeBlock = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self removeCurrentPlayerItemObserver:self.player.currentItem];
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        [self ul_configPlayer];
        [self ul_addNotification];
    }
    return self;
}

- (void)setMute:(BOOL)mute{
    _mute = mute;
    _player.muted = _mute;
}

- (void)setStatus:(ULVideoPlayerStatus)status{
    _status = status;
    if (_AVPlayerStatusChangeBlock) {
        _AVPlayerStatusChangeBlock(status);
    }
}

- (void)ul_startLoadAndAutoPlay{
    _resourceLoader = [[ULAVAssetResourceLoader alloc]init];
    _playerItem = [_resourceLoader playerItemWithURL:self.videoUrl];
    
    [self removeCurrentPlayerItemObserver:_player.currentItem];
    [_player replaceCurrentItemWithPlayerItem:_playerItem];
    [self addCurrentPlayerItemObserver:_player.currentItem];
    
    [_player play];
    _paused = NO;
    self.status = ULVideoPlayerStatusLoading;
}

- (void)addCurrentPlayerItemObserver:(AVPlayerItem *)playerItem {
    [playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackBufferEmpty" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"playbackLikelyToKeepUp" options:NSKeyValueObservingOptionNew context:nil];
    [playerItem addObserver:self forKeyPath:@"loadedTimeRanges" options:NSKeyValueObservingOptionNew context:nil];
}

- (void)removeCurrentPlayerItemObserver:(AVPlayerItem *)playerItem {
    [playerItem removeObserver:self forKeyPath:@"status"];
    [playerItem removeObserver:self forKeyPath:@"playbackBufferEmpty"];
    [playerItem removeObserver:self forKeyPath:@"playbackLikelyToKeepUp"];
    [playerItem removeObserver:self forKeyPath:@"loadedTimeRanges"];
}


- (void)ul_cancelLoadAndPause{
    [_player pause];
    self.status = ULVideoPlayerStatusPaused;
    [_resourceLoader cancel];
    _paused = YES;
}

- (void)ul_configPlayer{
    _player = [[AVPlayer alloc] init];
    _player.muted = self.mute;
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    _playerLayer.frame = self.bounds;
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer insertSublayer:_playerLayer atIndex:0];
}

- (void)ul_addNotification{
    //播放完成通知
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayDidEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:nil];
    
}

- (void)moviePlayDidEnd:(NSNotification *)noti{
    AVPlayerItem *item = noti.object;
    if (item) {
        AVURLAsset *asset = (AVURLAsset*)item.asset;
        AVURLAsset *selfItem = (AVURLAsset*)self.playerItem.asset;
        if ([asset.URL.absoluteString isEqualToString:selfItem.URL.absoluteString]) {
            if (!_paused) {
                [_playerItem seekToTime:kCMTimeZero];
                [_player play];
            }
        }
    }
}

#pragma mark-
#pragma mark KVO - status
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context {
    AVPlayerItem *item = (AVPlayerItem *)object;
    
    if ([keyPath isEqualToString:@"status"]) {
        AVPlayerStatus status = [[change objectForKey:@"new"] intValue]; // 获取更改后的状态
        if (status == AVPlayerStatusFailed) {
            self.status = ULVideoPlayerStatusFail;
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        //视频当前的播放进度
        NSTimeInterval current = CMTimeGetSeconds(_player.currentTime);
        //视频的总长度
        NSTimeInterval total = CMTimeGetSeconds(_player.currentItem.duration);
        
        NSTimeInterval loadedTime = [self availableDurationWithplayerItem:_playerItem];
        
        if (loadedTime - current > 2 || loadedTime == total) {
            
        }else{

        }
    }else if ([keyPath isEqualToString:@"playbackBufferEmpty"]) { //监听播放器在缓冲数据的状态
        self.status = ULVideoPlayerStatusLoading;
    }else if ([keyPath isEqualToString:@"playbackLikelyToKeepUp"]){
        if (!_paused) {
            [_player play];
            self.status = ULVideoPlayerStatusPlaying;
        }
    }
}
- (NSTimeInterval)availableDurationWithplayerItem:(AVPlayerItem *)playerItem
{
    NSArray *loadedTimeRanges = [playerItem loadedTimeRanges];
    CMTimeRange timeRange = [loadedTimeRanges.firstObject CMTimeRangeValue];// 获取缓冲区域
    NSTimeInterval startSeconds = CMTimeGetSeconds(timeRange.start);
    NSTimeInterval durationSeconds = CMTimeGetSeconds(timeRange.duration);
    NSTimeInterval result = startSeconds + durationSeconds;// 计算缓冲总进度
    return result;
}
@end
