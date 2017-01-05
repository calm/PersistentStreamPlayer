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

/* WARNING: seeking may create inconsistent behavior. This feature is thus "in beta"
 * Seeking while making the file persist on disk in the proper byte order is non-trivial
 * If you want to help make this robust, a pull request would be eagerly welcomed
 */
- (void)seekToTime:(NSTimeInterval)time;

@end
