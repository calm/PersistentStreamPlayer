#import <Foundation/Foundation.h>

@interface FileUtils : NSObject

+ (BOOL)saveData:(NSData *)data toURL:(NSURL *)url;
+ (BOOL)moveFileFromURL:(NSURL *)oldURL toURL:(NSURL *)newURL;
+ (NSURL *)randomTempFileURL;

@end
