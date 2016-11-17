## PersistentStreamPlayer

Handles the playing of an audio file while streaming, **and** saves the data to a local URL as soon as the stream completes.  Battle-tested in the production version of [Calm](https://www.calm.com/ios)

### Installation

Add this to your [Podfile](https://cocoapods.org/)

```
pod 'PersistentStreamPlayer'
```

### Usage

```
PersistentStreamPlayer *remoteAudioPlayer = [[PersistentStreamPlayer alloc] initWithRemoteURL:myHTTPURL
                                                                                     localURL:myFileURL];
remoteAudioPlayer.delegate = self;
[remoteAudioPlayer play];
```

### Features

* streaming of audio file, starting playback as soon as first data is available
* **also** saves streamed data to a file URL as soon as the buffer completes
* simple `play`, `pause` and `destroy` methods (`destroy` clears all memory resources)
* ability to seamlessly loop the audio file. call `player.looping = YES`
* exposes `timeBuffered`, helpful for displaying buffer progress bars in the UI
* handles re-starting the audio file after the buffer stream stalls (e.g. slow network)
* does not keep audio file data in memory, so that it supports large files that don't fit in RAM

The `PersistentStreamPlayerDelegate` protocol has some helpful event indicators, all optional:

```
/* called when the data is saved to localURL */
- (void)persistentStreamPlayerDidPersistAsset:(PersistentStreamPlayer *)player;

/* called when the audio file completed */
- (void)persistentStreamPlayerDidFinishPlaying:(PersistentStreamPlayer *)player;

/* called when the play head reaches the buffer head */
- (void)persistentStreamPlayerStreamingDidStall:(PersistentStreamPlayer *)player;

/* called as soon as the asset loads with a duration, helpful for showing a duration clock */
- (void)persistentStreamPlayerDidLoadAsset:(PersistentStreamPlayer *)player;

/* on failure to load asset */
- (void)persistentStreamPlayerDidFailToLoadAsset:(PersistentStreamPlayer *)player;
```
