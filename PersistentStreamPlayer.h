#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class PersistentStreamPlayer;
@protocol PersistentStreamPlayerDelegate <NSObject>

@optional
- (void)persistentStreamPlayerDidPersistAsset:(nonnull PersistentStreamPlayer *)player;

- (void)persistentStreamPlayerDidFinishPlaying:(nonnull PersistentStreamPlayer *)player;
- (void)persistentStreamPlayerStreamingDidStall:(nonnull PersistentStreamPlayer *)player;

- (void)persistentStreamPlayerDidLoadAsset:(nonnull PersistentStreamPlayer *)player;
- (void)persistentStreamPlayerDidFailToLoadAsset:(nonnull PersistentStreamPlayer *)player;

@end

@interface PersistentStreamPlayer : NSObject

- (nullable instancetype)initWithRemoteURL:(nonnull NSURL *)remoteURL
                                  localURL:(nonnull NSURL *)localURL;

@property (nonatomic, readonly) AVPlayer *player;
@property (nonatomic, weak, nullable) id<PersistentStreamPlayerDelegate> delegate;
@property (nonatomic, assign) BOOL looping;
@property (nonatomic, readonly) BOOL playing;
@property (nonatomic, assign) float volume;

- (void)play;
- (void)pause;
- (void)destroy;

@property (nonatomic, readonly) BOOL isAssetLoaded;
@property (nonatomic, readonly) NSTimeInterval duration;
@property (nonatomic, readonly) NSTimeInterval timeBuffered;
@property (nonatomic, readonly) NSTimeInterval currentTime;

/* due to buffering model, doesn't yet support shifting forward */
- (void)shiftAudioBack:(NSTimeInterval)duration;

@end
