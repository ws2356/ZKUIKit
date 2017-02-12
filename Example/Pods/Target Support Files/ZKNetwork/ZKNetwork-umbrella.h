#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "RequestUtils.h"
#import "ZKDownloadRecord.h"
#import "ZKNetwork+Private.h"
#import "ZKNetwork.h"

FOUNDATION_EXPORT double ZKNetworkVersionNumber;
FOUNDATION_EXPORT const unsigned char ZKNetworkVersionString[];

