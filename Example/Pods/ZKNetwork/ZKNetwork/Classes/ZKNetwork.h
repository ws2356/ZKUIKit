//
//  ZKNetwork.h
//  SmartStudy
//
//  Created by wansong on 7/24/16.
//  Copyright © 2016 Innobuddy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

///should cancel and then retry on next request
typedef NS_ENUM(NSInteger, ZKNetworkDownloadStatus) {
//  ZKNetworkDownloadStatusWaiting, //todo
  ZKNetworkDownloadStatusRunning = 1,
  ZKNetworkDownloadStatusPaused,
  ZKNetworkDownloadStatusCanceled,
  ZKNetworkDownloadStatusCompleted,
  ZKNetworkDownloadStatusError,
};

///progressInfo: {ZKNetworkDownloadedBytesKey, ZKNetworkTotalBytesKey, ZKNetworkEstimatedRemainingTimeKey}
typedef void (^ZKNetworkProgressBlock)(NSDictionary *progressInfo);

///@brief int64_t wrapped in NSNumber
extern NSString * const ZKNetworkDownloadedBytesKey;
///@brief int64_t wrapped in NSNumber
extern NSString * const ZKNetworkTotalBytesKey;
///@brief int64_t wrapped in NSNumber
extern NSString * const ZKNetworkEstimatedRemaingingTimeKey;

//errorInfo: {ZKNetworkLocalErrorKey, ZKNetworkRemoteHttpStatusCodeKey, ZKNetworkDownloadStatusKey, ZKNetworkErrorMsgKey}
//taskInfo: {ZKNetworkUrlKey}
typedef void (^ZKNetworkCompletionBlock)(NSDictionary *errorInfo, NSDictionary *taskInfo);
typedef ZKNetworkCompletionBlock ResumeBlock;

///@brief used in parameter of completion block
extern NSString * const ZKNetworkLocalErrorKey;
extern NSString * const ZKNetworkRemoteHttpStatusCodeKey;
extern NSString * const ZKNetworkErrorMsgKey;
extern NSString * const ZKNetworkDownloadStatusKey;
extern NSString * const ZKNetworkUrlKey;

///@brief used in parameter of onRegister callback
extern NSString * const ZKNetworkIsReusedKey;


typedef void (^FailureCallback)(NSError *);

// 所有的内部维护下载记录的操作均在operationQueue， 也就是session.delegateQueue上进行
// 所有的回调block在mainqueue上调用，除非，因为参数错误等原因，操作没有真正执行，此时处理的方式是回调之后立即返回
@interface ZKNetwork : NSObject

+ (instancetype)sharedInstance;

- (void)start;

@property (copy, nonatomic) dispatch_block_t onDidHandleBackgroundSessionEvents;

- (void)download:(NSString*)remoteUrl
          sender:(id)sender
         onResume:(ResumeBlock)onResume
      onProgress:(ZKNetworkProgressBlock)onProgress
    onCompletion:(ZKNetworkCompletionBlock)onCompletion
      onRegister:(dispatch_block_t)onRegister;

- (void)removeListenerSender:(id)sender;

// pauseAll，再resumeAll会导致注册的各种回调丢失，但是不影响下载任务继续进行。可以通过download:sender:onResume...绑定新的回调，也可以进行pause，cancel等操作
- (void)pauseAllDownloadCompletion:(dispatch_block_t)completion;
- (void)resumeAllPausedTasksCompletion:(dispatch_block_t)completion;

// ZKNetwork会管理下载完成的文件，并在数据库中维护下载记录，如果调用retrieveDownloadFileForUrl，会移动文件到指定位置并清空下载记录
// 相当于“取走了下载的文件”
- (void)retrieveDownloadFileForUrl:(NSString*)remoteUrl
                  destinationPath:(NSString*)destPath
                        onSuccess:(dispatch_block_t)onSuccess
                        onFailure:(FailureCallback)onFailure;

- (void)cancelDownload:(NSString*)remoteUrl
              callback:(dispatch_block_t)callback;

- (void)pauseDownload:(NSString*)remoteUrl
             callback:(dispatch_block_t)callback;

// 此操作必须在operationQueue上执行，不然会有线程安全问题
- (NSDictionary*)downloadRecordsForUrls:(NSArray<NSString *> *)urls;

+ (NSString*)encodeRemoteUrlToLocalPath:(NSString*)urlStr;

// 默认开启后台传输功能，如果禁止，那么在app进入后台时暂停全部任务
@property (assign, nonatomic) BOOL enableBackgroundMode;

@property (readonly, nonatomic) NSOperationQueue *operationQueue;

@end
