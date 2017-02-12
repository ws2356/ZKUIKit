//
//  M3U8CacheManager.h
//  ServerInApp
//
//  Created by wansong on 12/31/16.
//  Copyright © 2016 zhike. All rights reserved.
//

#import <Foundation/Foundation.h>

// 播放器请求m3u8文件切片时，嵌入的服务器同步的下载切片数据后返回，实现边下边播
@interface ZKVideoCacheManager : NSObject

+ (void)start;
+ (BOOL)clearM3u8Cache:(NSError **)error;
+ (unsigned long long)cacheSize;

@end
