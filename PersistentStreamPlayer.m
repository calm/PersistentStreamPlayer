/* see http://vombat.tumblr.com/post/86294492874/caching-audio-streamed-using-avplayer
 * see https://gist.github.com/anonymous/83a93746d1ea52e9d23f
 */

#import "PersistentStreamPlayer.h"
#import "FileUtils.h"
#import <MobileCoreServices/MobileCoreServices.h>

@interface PersistentStreamPlayer () <NSURLConnectionDataDelegate, AVAssetResourceLoaderDelegate>

@property (nonatomic, strong) NSURL *remoteURL;
@property (nonatomic, strong) NSURL *localURL;
@property (nonatomic, strong) NSURL *tempURL;

@property (nonatomic, assign) NSUInteger fullAudioDataLength;
@property (nonatomic, assign) NSUInteger loadedAudioDataLength;

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSHTTPURLResponse *response;
@property (nonatomic, strong) NSMutableArray *pendingRequests;

@property (nonatomic, strong) NSTimer *healthCheckTimer;

@property (nonatomic, strong) NSString *originalURLScheme;

@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, assign) BOOL hasForcedDurationLoad;
@property (nonatomic, assign) BOOL isStalled;

@property (nonatomic, assign) BOOL connectionHasFinishedLoading;

@property (nonatomic, strong) AVAudioPlayer *loopingLocalAudioPlayer;

@property (nonatomic, assign) BOOL isDestroyed;

@property (nonatomic, assign) BOOL isResumed;

@end

@implementation PersistentStreamPlayer

- (instancetype)initWithRemoteURL:(NSURL *)remoteURL
                         localURL:(NSURL *)localURL
{
    if (!remoteURL || !localURL) {
        return nil;
    }

    self = [super init];
    if (self) {
        self.remoteURL = remoteURL;
        self.localURL = localURL;

        self.tempURL = [FileUtils randomTempFileURL];

        [self prepareToPlay];
        [self addObservers];
    }
    return self;
}

#pragma mark - Actions

- (void)prepareToPlay
{
    self.pendingRequests = [NSMutableArray array];

    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:self.audioRemoteStreamingURL options:nil];
    [asset.resourceLoader setDelegate:self queue:dispatch_get_main_queue()];
    AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset automaticallyLoadedAssetKeys:@[@"duration"]];
    self.player = [[AVPlayer alloc] initWithPlayerItem:playerItem];
    [self.player.currentItem addObserver:self
                              forKeyPath:@"status"
                                 options:NSKeyValueObservingOptionNew
                                 context:NULL];
    
    //uncomment if it will help
//    self.player.automaticallyWaitsToMinimizeStalling = NO;
}

- (void)play
{
    [self.player play];
    [self startHealthCheckTimer];
    [self.loopingLocalAudioPlayer play];
}

- (void)pause
{
    [self.player pause];
    [self stopHealthCheckTimer];
    [self.loopingLocalAudioPlayer pause];
}

/* See "in beta" warning in header file. */
- (void)seekToTime:(NSTimeInterval)time
{
    CMTime seekTime = CMTimeMakeWithSeconds(MAX(time, 0), self.player.currentTime.timescale);
    [self.player seekToTime:seekTime];
}

#pragma mark - NSURLConnection delegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    if (!self.isResumed) {
        self.response = (NSHTTPURLResponse *)response;
        self.loadedAudioDataLength = 0;
        self.fullAudioDataLength = self.response.expectedContentLength;
    }
    
    [self processPendingRequests];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    self.loadedAudioDataLength += data.length;
    [self appendDataToTempFile:data];
    [self processPendingRequests];
    
    if (self.isResumed) {
        self.isResumed = NO;
        self.isStalled = NO;
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    self.connectionHasFinishedLoading = YES;
    
    [self processPendingRequests];
    [FileUtils moveFileFromURL:self.tempURL toURL:self.localURL];
    
    if ([self.delegate respondsToSelector:@selector(persistentStreamPlayerDidPersistAsset:)]) {
        [self.delegate persistentStreamPlayerDidPersistAsset:self];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error{
    
    NSArray *pendingRequests = [self.pendingRequests copy];
    for (AVAssetResourceLoadingRequest *loadingRequest in pendingRequests) {
        NSURLComponents * component = [[NSURLComponents alloc] initWithURL:loadingRequest.request.URL resolvingAgainstBaseURL:NO];
        component.scheme = self.originalURLScheme ?: @"http";
        
        if ([component.URL.absoluteString isEqualToString: connection.currentRequest.URL.absoluteString] ) {
            [loadingRequest finishLoadingWithError:error];
            [self.pendingRequests removeObject:loadingRequest];
        }
    }
    
    if (!self.connectionHasFinishedLoading) {
        
        [self.connection cancel];
        self.connection = nil;
        
        if (self.pendingRequests.count == 0) {
            if ([self.delegate respondsToSelector:@selector(persistentStreamPlayerDidFailToLoadAsset:)]) {
                [self.delegate persistentStreamPlayerDidFailToLoadAsset:self];
            }
        }
        
    }
}

- (void)resumeConnection {
    NSURL *interceptedURL = self.audioRemoteStreamingURL;
    NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:interceptedURL resolvingAgainstBaseURL:NO];
    actualURLComponents.scheme = self.originalURLScheme ?: @"http";
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:actualURLComponents.URL];
    if (self.loadedAudioDataLength > 0) {
        NSString *range = [NSString stringWithFormat:@"bytes=%i-", self.loadedAudioDataLength];
        [request setValue:range forHTTPHeaderField:@"Range"];
    }
    
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
    [self.connection setDelegateQueue:[NSOperationQueue mainQueue]];
    [self.connection start];
    
    self.isResumed = YES;
}

- (void)appendDataToTempFile:(NSData *)data
{
    if(!self.tempFileExists) {
        [FileUtils saveData:data toURL:self.tempURL];
    } else {
        NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:self.tempURL.path];;
        [fileHandle seekToEndOfFile];
        [fileHandle writeData:data];
    }
}

#pragma mark - Getters & Setters

- (BOOL)playing
{
    if (self.loopingLocalAudioPlayer) {
        return self.loopingLocalAudioPlayer.playing;
    }
    return self.player.rate != 0 && !self.player.error;
}

- (BOOL)tempFileExists
{
    return [[NSFileManager defaultManager] fileExistsAtPath:self.tempURL.path];
}

- (NSData *)dataFromFileInRange:(NSRange)range
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:self.currentURLForDataFile.path];;
    [fileHandle seekToFileOffset:range.location];
    return [fileHandle readDataOfLength:range.length];
}

- (NSURL *)currentURLForDataFile
{
    return self.connectionHasFinishedLoading ? self.localURL : self.tempURL;
}

- (NSURL *)audioRemoteStreamingURL
{
    if (!self.remoteURL) {
        return nil;
    }
    
    NSURLComponents *components = [[NSURLComponents alloc] initWithURL:self.remoteURL resolvingAgainstBaseURL:NO];
    self.originalURLScheme = components.scheme;
    components.scheme = @"streaming";
    return components.URL;
}

- (float)volume
{
    return self.loopingLocalAudioPlayer ? self.loopingLocalAudioPlayer.volume : self.player.volume;
}

- (void)setVolume:(float)volume
{
    if (self.loopingLocalAudioPlayer) {
        self.loopingLocalAudioPlayer.volume = volume;
    } else if (self.player) {
        self.player.volume = volume;
    }
}

- (BOOL)muted
{
	return self.player.muted;
}

- (void)setMuted:(BOOL)muted
{
	self.player.muted = muted;
}

- (BOOL)isAssetLoaded
{
    AVKeyValueStatus durationStatus = [self.player.currentItem.asset statusOfValueForKey:@"duration" error:NULL];
    return durationStatus == AVKeyValueStatusLoaded && self.player.status == AVPlayerStatusReadyToPlay;
}

- (NSTimeInterval)duration
{
    if (!self.isAssetLoaded) {
        return self.fullAudioDataLength;
        /*
         return 5 * 60.0; // give it a good guess of 5 min before asset loads...
         */
    }
    return CMTimeGetSeconds(self.player.currentItem.asset.duration);
}

- (NSTimeInterval)timeBuffered
{
    CMTimeRange timeRange = [[self.player.currentItem.loadedTimeRanges lastObject] CMTimeRangeValue];
    return CMTimeGetSeconds(timeRange.start) + CMTimeGetSeconds(timeRange.duration);
}

- (NSTimeInterval)currentTime
{
    if (self.loopingLocalAudioPlayer) {
        return self.loopingLocalAudioPlayer.currentTime;
    }
    return CMTimeGetSeconds(self.player.currentTime);
}

#pragma mark - AVURLAsset resource loading

- (void)processPendingRequests
{
    NSMutableArray *requestsCompleted = [NSMutableArray array];

    for (AVAssetResourceLoadingRequest *loadingRequest in self.pendingRequests) {
        [self fillInContentInformation:loadingRequest.contentInformationRequest];

        BOOL didRespondCompletely = [self respondWithDataForRequest:loadingRequest.dataRequest];
        if (didRespondCompletely) {
            [requestsCompleted addObject:loadingRequest];
            [loadingRequest finishLoading];
        }
    }

    [self.pendingRequests removeObjectsInArray:requestsCompleted];
}

- (void)fillInContentInformation:(AVAssetResourceLoadingContentInformationRequest *)contentInformationRequest
{
    if (contentInformationRequest == nil || self.response == nil) {
        return;
    }

    NSString *mimeType = [self.response MIMEType];
    CFStringRef contentType = UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (__bridge CFStringRef)(mimeType), NULL);

    contentInformationRequest.byteRangeAccessSupported = YES;
    contentInformationRequest.contentType = CFBridgingRelease(contentType);
    contentInformationRequest.contentLength = [self.response expectedContentLength];
}

- (BOOL)respondWithDataForRequest:(AVAssetResourceLoadingDataRequest *)dataRequest
{
    long long startOffset = dataRequest.requestedOffset;
    if (dataRequest.currentOffset != 0) {
        startOffset = dataRequest.currentOffset;
    }

    // Don't have any data at all for this request
    if (self.fullAudioDataLength < startOffset) {
        return NO;
    }

    // This is the total data we have from startOffset to whatever has been downloaded so far
    NSUInteger unreadBytes = self.fullAudioDataLength - (NSUInteger)startOffset;

    // Respond with whatever is available if we can't satisfy the request fully yet
    NSUInteger numberOfBytesToRespondWith = MIN((NSUInteger)dataRequest.requestedLength, unreadBytes);

    NSRange range = NSMakeRange((NSUInteger)startOffset, numberOfBytesToRespondWith);
    NSData *subData = [self dataFromFileInRange:range];
    [dataRequest respondWithData:subData];

    long long endOffset = startOffset + dataRequest.requestedLength;
    BOOL didRespondFully = self.fullAudioDataLength >= endOffset;
    return didRespondFully;
}

- (BOOL)                 resourceLoader:(AVAssetResourceLoader *)resourceLoader
shouldWaitForLoadingOfRequestedResource:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self.pendingRequests addObject:loadingRequest];

    if (self.connectionHasFinishedLoading) {
        [self processPendingRequests];
        return YES;
    }

    if (!self.connection) {
        self.connectionHasFinishedLoading = NO;

        NSURL *interceptedURL = loadingRequest.request.URL;
        NSURLComponents *actualURLComponents = [[NSURLComponents alloc] initWithURL:interceptedURL resolvingAgainstBaseURL:NO];
        actualURLComponents.scheme = self.originalURLScheme ?: @"http";

        NSURLRequest *request = [NSURLRequest requestWithURL:actualURLComponents.URL];
        self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
        [self.connection setDelegateQueue:[NSOperationQueue mainQueue]];
        [self.connection start];
    }

    return YES;
}

- (void)resourceLoader:(AVAssetResourceLoader *)resourceLoader didCancelLoadingRequest:(AVAssetResourceLoadingRequest *)loadingRequest
{
    [self.pendingRequests removeObject:loadingRequest];
}

#pragma mark - Observing

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (self.player.currentItem.status == AVPlayerItemStatusReadyToPlay
        && self.playing) {
        [self.player play];
    }
}

- (void)addObservers
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:[self.player currentItem]];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidStall:)
                                                 name:AVPlayerItemPlaybackStalledNotification
                                               object:[self.player currentItem]];
}

- (void)removeObservers
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - AVPlayerItem

- (void)playerItemDidStall:(NSNotification *)notification
{
    self.isStalled = YES;
    
    if ([self.delegate respondsToSelector:@selector(persistentStreamPlayerStreamingDidStall:)]) {
        [self.delegate persistentStreamPlayerStreamingDidStall:self];
    }
}

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    if ([self.delegate respondsToSelector:@selector(persistentStreamPlayerDidFinishPlaying:)]) {
        [self.delegate persistentStreamPlayerDidFinishPlaying:self];
    }
    [self stopHealthCheckTimer];
    [self tryToStartLocalLoop];
}

- (void)startHealthCheckTimer
{
    if (self.healthCheckTimer) {
        [self stopHealthCheckTimer];
    }
    
    [self healthCheckTimerDidFire]; // fires once immediately
    self.healthCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                             target:self
                                                           selector:@selector(healthCheckTimerDidFire)
                                                           userInfo:nil
                                                            repeats:YES];
}

- (void)stopHealthCheckTimer
{
    [self.healthCheckTimer invalidate];
    self.healthCheckTimer = nil;
}

/* this method is basically a health check that is run consistently to keep things healthy during streaming */
- (void)healthCheckTimerDidFire
{
    if (self.isDestroyed) {
        return;
    }
    [self loadAssetIfNecessary];
    [self tryToPlayIfStalled];
}

- (void)tryToPlayIfStalled
{
    if (!self.isStalled) {
        
        if (self.player.rate != 0
            && self.player.timeControlStatus == AVPlayerTimeControlStatusWaitingToPlayAtSpecifiedRate
            && [self.player.reasonForWaitingToPlay isEqualToString:AVPlayerWaitingToMinimizeStallsReason]) {
            [self.player playImmediatelyAtRate:self.player.rate];
        }
        
        return;
    }

    if (self.player.currentItem.playbackLikelyToKeepUp ||
        (self.timeBuffered - self.currentTime) > 5.0)
    {
        self.isStalled = NO;
        [self play];
    }
}

- (void)tryToStartLocalLoop
{
    if (!self.looping) {
        return;
    }

    self.loopingLocalAudioPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:self.localURL
                                                                          error:nil];
    [self.loopingLocalAudioPlayer prepareToPlay];
    self.loopingLocalAudioPlayer.numberOfLoops = -1;
    self.loopingLocalAudioPlayer.volume = 1.0;
    [self.loopingLocalAudioPlayer play];
}

- (void)loadAssetIfNecessary
{
    if (self.hasForcedDurationLoad) {
        return;
    }
    
    if (self.isAssetLoaded) {
        return;
    }

    if (self.player.status == AVPlayerStatusReadyToPlay) {
        [self forceLoadOfDuration];
        self.hasForcedDurationLoad = YES;
        return;
    }
    if (self.player.status == AVPlayerStatusFailed) {
        if ([self.delegate respondsToSelector:@selector(persistentStreamPlayerDidFailToLoadAsset:)]) {
            [self.delegate persistentStreamPlayerDidFailToLoadAsset:self];
        }
        return;
    }
}

- (void)forceLoadOfDuration
{
    __weak typeof(self) weakSelf = self;
    [self.player.currentItem.asset loadValuesAsynchronouslyForKeys:@[@"duration"]
                                                 completionHandler:^{
                                                     if(weakSelf) {
                                                         PersistentStreamPlayer* strongSelf = weakSelf;
                                                         if (strongSelf.isAssetLoaded) {
                                                             if ([strongSelf.delegate respondsToSelector:@selector(persistentStreamPlayerDidLoadAsset:)]) {
                                                                 [strongSelf.delegate persistentStreamPlayerDidLoadAsset:strongSelf];
                                                             }
                                                         } else {
                                                             if ([strongSelf.delegate respondsToSelector:@selector(persistentStreamPlayerDidFailToLoadAsset:)]) {
                                                                 [strongSelf.delegate persistentStreamPlayerDidFailToLoadAsset:strongSelf];
                                                             }
                                                         }
                                                     }
                                                 }];
}

#pragma mark - Memory management

- (void)dealloc
{
    [self destroy];
}

- (void)destroy
{
    if (self.isDestroyed) {
        return;
    }
    self.isDestroyed = YES;
    
    [self removeObservers];
    
    [self stopHealthCheckTimer];
    [self.player pause];
    
    [self.player.currentItem removeObserver:self forKeyPath:@"status"];
    [self.player.currentItem cancelPendingSeeks];
    [self.player.currentItem.asset cancelLoading];
    self.player.rate = 0.0;
    self.player = nil;
    
    [self.connection cancel];
    self.connection = nil;
    
    [self.loopingLocalAudioPlayer stop];
    self.loopingLocalAudioPlayer = nil;
}

@end
