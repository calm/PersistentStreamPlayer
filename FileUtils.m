#import "FileUtils.h"

@implementation FileUtils

+ (BOOL)saveData:(NSData *)data
           toURL:(NSURL *)url
{
    NSError *error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:url.path.stringByDeletingLastPathComponent
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error) {
        return NO;
    }
    return [data writeToURL:url atomically:YES];
}

+ (BOOL)moveFileFromURL:(NSURL *)oldURL
                  toURL:(NSURL *)newURL
{
    [[NSFileManager defaultManager] createDirectoryAtPath:newURL.path.stringByDeletingLastPathComponent
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSError *error = nil;
    [[NSFileManager defaultManager] copyItemAtPath:oldURL.path
                                            toPath:newURL.path
                                             error:&error];

    [[NSFileManager defaultManager] removeItemAtPath:oldURL.path
                                               error:nil];

    return !error;
}

+ (NSURL *)randomTempFileURL
{
    NSString *directory = NSTemporaryDirectory();
    NSString *fileName = [NSUUID UUID].UUIDString;
    return [NSURL fileURLWithPathComponents:@[directory, fileName]];
}

@end
