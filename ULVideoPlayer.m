//
//  ULVideoPlayer.m
//  UpLive
//
//  Created by 王传正 on 13/10/2017.
//  Copyright © 2017 AsiaInnovations. All rights reserved.
//

#import "ULVideoPlayer.h"
#import "ULAVAssetResourceLoader.h"

static int kMaxRetryCount = 3;

@interface ULVideoPlayer()

@property (nonatomic, strong) AVPlayer               *player;
@property (nonatomic, strong) AVPlayerItem           *playerItem;
@property (nonatomic, strong) AVURLAsset             *urlAsset;
@property (nonatomic, strong) AVPlayerLayer          *playerLayer;

@property (nonatomic, strong) ULAVAssetResourceLoader *resourceLoader;

@property (nonatomic, assign) BOOL paused;
@property (nonatomic, assign) int retryCount;

@end

@implementation ULVideoPlayer

- (void)dealloc{
    _AVPlayerStatusChangeBlock = nil;
    [_resourceLoader cancel];
    [self removeCurrentPlayerItemObserver:_playerItem];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithFrame:(CGRect)frame{
    self = [super initWithFrame:frame];
    if (self) {
        self.retryCount = 0;
        
        [self ul_configPlayer];
        [self ul_addNotification];
    }
    return self;
}

- (void)setMute:(BOOL)mute{
    _mute = mute;
    _player.muted = _mute;
}

- (void)setVideoGravity:(AVLayerVideoGravity)videoGravity{
    _videoGravity = videoGravity;
    _playerLayer.videoGravity = _videoGravity;
}

- (void)setFrame:(CGRect)frame{
    [super setFrame:frame];
    _playerLayer.frame = self.bounds;
}

- (void)setStatus:(ULVideoPlayerStatus)status{
    _status = status;
    if (_AVPlayerStatusChangeBlock) {
        _AVPlayerStatusChangeBlock(status);
    }
}

- (void)ul_startLoadAndAutoPlay{
    _retryCount = 0;
    
    [self ul_startLoad];
}

- (void)ul_startLoad{
    [self removeCurrentPlayerItemObserver:_playerItem];
    _playerItem = [_resourceLoader playerItemWithURL:self.videoUrl];
    [_player replaceCurrentItemWithPlayerItem:_playerItem];
    [_player play];
    [self addCurrentPlayerItemObserver:_playerItem];
    
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

- (NSTimeInterval)ul_getCurrentTime{
    
    return CMTimeGetSeconds(self.player.currentTime);
}

- (void)play{
    _paused = NO;
    [_player play];
}

- (void)pause{
    _paused = YES;
    [_player pause];
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
    
    if ([_player respondsToSelector:@selector(setAutomaticallyWaitsToMinimizeStalling:)]) {
        _player.automaticallyWaitsToMinimizeStalling = NO;
    }
    
    _playerLayer = [AVPlayerLayer playerLayerWithPlayer:self.player];
    _playerLayer.frame = self.bounds;
    _playerLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.layer insertSublayer:_playerLayer atIndex:0];
    
    _resourceLoader = [[ULAVAssetResourceLoader alloc]init];
}

- (void)reCongifPlayer{
    if (_retryCount >= kMaxRetryCount) {
        return;
    }
    _retryCount ++;
    
    [_resourceLoader cancel];
    [self removeCurrentPlayerItemObserver:_playerItem];
    _playerItem = nil;
    _player = nil;
    
    if (_playerLayer.superlayer) {
        [_playerLayer removeFromSuperlayer];
        _playerLayer = nil;
    }
    
    [self ul_configPlayer];
    
    [self ul_startLoad];
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
        AVPlayerItemStatus status = [[change objectForKey:@"new"] intValue]; // 获取更改后的状态
        if (status == AVPlayerItemStatusFailed) {
            self.status = ULVideoPlayerStatusFail;
            [self.resourceLoader removeCache];
            [self reCongifPlayer];
        }
    } else if ([keyPath isEqualToString:@"loadedTimeRanges"]) {
        //视频当前的播放进度
        NSTimeInterval current = CMTimeGetSeconds(_player.currentTime);
        //视频的总长度
        NSTimeInterval total = CMTimeGetSeconds(_player.currentItem.duration);
        
        NSTimeInterval loadedTime = [self availableDurationWithplayerItem:_playerItem];
        
        if (loadedTime - current > 2 || loadedTime == total) {
            if (!_paused) {
                [_player play];
                self.status = ULVideoPlayerStatusPlaying;
            }
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
