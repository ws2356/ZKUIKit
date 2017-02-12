//
//  ZKNetwork+Private.h
//  SmartStudy
//
//  Created by wansong.mbp.work on 7/29/16.
//  Copyright © 2016 Innobuddy Inc. All rights reserved.
//

#ifndef ZKNetwork_Private_h
#define ZKNetwork_Private_h

#import "ZKNetwork.h"


@interface ZKNetwork () <NSURLSessionDownloadDelegate>

+ (NSString*)localPathForUrl:(NSString*)remoteUrl;

+ (NSString*)dbPath;

+ (NSString*)downloadPath;

+ (NSString*)rootPath;


@end


#endif /* ZKNetwork_Private_h */
