#import "MekasaExceptionCatcher.h"

@implementation MekasaExceptionCatcher

+ (BOOL)performBlock:(void(NS_NOESCAPE ^)(void))block
                error:(NSError *_Nullable *_Nullable)error {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error != NULL) {
            NSMutableDictionary *info = [NSMutableDictionary dictionary];
            info[NSLocalizedDescriptionKey] = exception.reason ?: exception.name ?: @"Unknown exception";
            if (exception.name != nil) {
                info[@"exception.name"] = exception.name;
            }
            if (exception.userInfo != nil) {
                info[@"exception.userInfo"] = exception.userInfo;
            }
            *error = [NSError errorWithDomain:@"MekasaException"
                                         code:0
                                     userInfo:info];
        }
        return NO;
    }
}

@end
