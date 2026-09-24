#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Catches Objective-C `NSException`s raised inside `block` and converts them to `NSError`.
/// Used so Google Sign-In's synchronous URL-scheme check cannot terminate the process.
@interface MekasaExceptionCatcher : NSObject

+ (BOOL)performBlock:(void(NS_NOESCAPE ^)(void))block
                error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
