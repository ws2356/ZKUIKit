//
//  ZKM3U8CacheManager+Private.h
//  ZKM3U8Cache
//
//  Created by wansong.mbp.work on 12/01/2017.
//  Copyright © 2017 zhike. All rights reserved.
//

#ifndef ZKM3U8CacheManager_Private_h
#define ZKM3U8CacheManager_Private_h

#import "ZKVideoCacheManager.h"

@interface ZKVideoCacheManager ()
// 把host替换成潜入的服务器的地址
+ (NSString*)cacheUrlForM3u8:(NSString*)m3u8Url;

@end


#endif /* ZKM3U8CacheManager_Private_h */
