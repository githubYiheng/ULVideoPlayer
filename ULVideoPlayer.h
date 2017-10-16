//
//  ULVideoPlayer.h
//  UpLive
//
//  Created by 王传正 on 13/10/2017.
//  Copyright © 2017 AsiaInnovations. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef enum : NSUInteger {
    ULVideoPlayerStatusPlaying = 1,
    ULVideoPlayerStatusLoading,
    ULVideoPlayerStatusPaused,
    ULVideoPlayerStatusFail
} ULVideoPlayerStatus;

@interface ULVideoPlayer : UIView

@property (nonatomic, assign) BOOL mute;

@property (nonatomic, strong) NSURL *videoUrl;

@property (nonatomic, readonly) ULVideoPlayerStatus status;

@property (nonatomic, copy) void (^AVPlayerStatusChangeBlock)(ULVideoPlayerStatus status);

- (void)ul_cancelLoadAndPause;
- (void)ul_startLoadAndAutoPlay;

@end
