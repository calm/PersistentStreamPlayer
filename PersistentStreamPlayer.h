#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "ManifestEntry.h"

@class PersistentStreamPlayer;
@protocol PersistentStreamPlayerDelegate <NSObject>

@required
- (void)persistentStreamPlayerDidPersistAsset:(PersistentStreamPlayer *)player;

- (void)persistentStreamPlayerDidFinishPlaying:(PersistentStreamPlayer *)player;
- (void)persistentStreamPlayerStreamingDidStall:(PersistentStreamPlayer *)player;

- (void)persistentStreamPlayerDidLoadAsset:(PersistentStreamPlayer *)player;
- (void)persistentStreamPlayerDidFailToLoadAsset:(PersistentStreamPlayer *)player;

@end

@interface PersistentStreamPlayer : NSObject

- (instancetype)initWithRemoteURL:(NSURL *)remoteURL
                         localURL:(NSURL *)localURL;

@property (nonatomic, weak) id<PersistentStreamPlayerDelegate> delegate;
@property (nonatomic, readonly) AVPlayer *player;

- (void)play;
- (void)pause;
- (void)destroy;

@property (nonatomic, readonly) BOOL isAssetLoaded;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval timeBuffered;
@property (nonatomic, readonly) NSTimeInterval currentTime;

@end
