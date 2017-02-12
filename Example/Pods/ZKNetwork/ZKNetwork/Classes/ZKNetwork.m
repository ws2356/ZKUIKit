//
//  ZKNetwork.m
//  SmartStudy
//
//  Created by wansong on 7/24/16.
//  Copyright © 2016 Innobuddy Inc. All rights reserved.
//

#import "ZKNetwork.h"
#import "ZKDownloadRecord.h"
#import "RequestUtils.h"
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <CocoaLumberjack/CocoaLumberjack.h>

#ifdef LOG_LEVEL_DEF
  #undef LOG_LEVEL_DEF
#endif

#define LOG_LEVEL_DEF myLibLogLevel
#ifdef DEBUG
#define myLibLogLevel DDLogLevelAll
#else
#define myLibLogLevel DDLogLevelWarning
#endif

#define LOG_ASYNC_ENABLED 0


///@brief used in parameter of progress block
NSString * const ZKNetworkDownloadedBytesKey = @"ZKNetworkDownloadedBytesKey";
NSString * const ZKNetworkTotalBytesKey = @"ZKNetworkTotalBytesKey";
NSString * const ZKNetworkEstimatedRemaingingTimeKey = @"ZKNetworkEstimatedRemaingingTimeKey";

///@brief used in parameter of completion block
NSString * const ZKNetworkLocalErrorKey = @"ZKNetworkLocalErrorKey";
NSString * const ZKNetworkRemoteHttpStatusCodeKey = @"ZKNetworkRemoteHttpStatusCodeKey";
NSString * const ZKNetworkDownloadStatusKey = @"ZKNetworkDownloadStatusKey";
NSString * const ZKNetworkErrorMsgKey = @"ZKNetworkErrorMsgKey";
NSString * const ZKNetworkTmpPathKey = @"ZKNetworkTmpPathKey";

///@brief used in parameter of onRegister callback 
NSString * const ZKNetworkIsReusedKey = @"ZKNetworkIsReusedKey";
NSString * const ZKNetworkUrlKey = @"ZKNetworkUrlKey";

///@brief these blocks will be cleared on error, completion and pause event
static NSString * const kZKNetworkProgressBlocksKey = @"kZKNetworkProgressBlocksKey";
static NSString * const kZKNetworkCompletionBlocksKey = @"kZKNetworkCompletionBlocksKey";
static NSString * const kResumeBlocksKey = @"kResumeBlocksKey";

static NSString * const kProgressThrottleInfoKey = @"kProgressThrottleInfoKey";

static NSString * const kBackgroundSessionIdentifier = @"com.smartstudy.zknetwork.backgroundsessionideitifier";

const NSInteger THROTTLE_SECONDS = 10;

@interface ZKNetwork () <NSURLSessionDownloadDelegate>

@property (strong, nonatomic) NSMutableDictionary<NSString*, NSMutableDictionary<NSString*, NSMutableDictionary*>*> *listeners;
@property (readonly, nonatomic) NSURLSession *session;
@property (strong, nonatomic) ZKDownloadRecord *downloadStatusManager;

@property (assign, nonatomic) UIBackgroundTaskIdentifier bgTask;
@end

void handleBackgroundEvents(id sender, SEL sel, UIApplication *app, NSString *identifier, dispatch_block_t completionHandler) {
  if ([identifier isEqualToString:kBackgroundSessionIdentifier]) {
    DDLogInfo(@"handling background session events within zknetwork");
    [[ZKNetwork sharedInstance] setOnDidHandleBackgroundSessionEvents:completionHandler];
  }else {
    SEL handleEventsForBackgroundURLSession = @selector(ZKNetwork:handleEventsForBackgroundURLSession:completionHandler:);
    if ([app.delegate respondsToSelector:handleEventsForBackgroundURLSession]) {
      DDLogInfo(@"handling background session events using customer implementation");
      NSMethodSignature *methodSig = [(NSObject*)app.delegate methodSignatureForSelector:handleEventsForBackgroundURLSession];
      NSInvocation *inv = [NSInvocation invocationWithMethodSignature:methodSig];
      [inv retainArguments];
      [inv setSelector:handleEventsForBackgroundURLSession];
      [inv setTarget:app.delegate];
      //arguments 0 and 1 are self and _cmd respectively, automatically set by NSInvocation
      [inv setArgument:&(app) atIndex:2];
      [inv setArgument:&(identifier) atIndex:3];
      [inv setArgument:&(completionHandler) atIndex:4];
      [inv invoke];
    }
  }
}

@implementation ZKNetwork {
  NSURLSession *_session;
}
@synthesize session = _session;

#pragma mark -- public
+ (instancetype)sharedInstance {
  static ZKNetwork *ret = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    ret = [[ZKNetwork alloc] init];
  });
  return ret;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.listeners = [NSMutableDictionary dictionary];
    self.bgTask = UIBackgroundTaskInvalid;
  }
  return self;
}

- (void)start {
  if (self.session) {
    return;
  }
  NSURLSessionConfiguration *config =
  [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:
   [[NSBundle mainBundle] bundleIdentifier]];
  config.sessionSendsLaunchEvents = YES;
  NSURLSession *session = [NSURLSession sessionWithConfiguration:config
                                                        delegate:self
                                                   delegateQueue:nil];
  Class delegate = [[UIApplication sharedApplication].delegate class];
  SEL handleEventsForBackgroundURLSession = @selector(ZKNetwork:handleEventsForBackgroundURLSession:completionHandler:);
  SEL originalSelector = @selector(application:handleEventsForBackgroundURLSession:completionHandler:);
  
  Method originalMethod = class_getInstanceMethod(delegate, originalSelector);
  if (!originalMethod) {
    if (!class_addMethod(delegate, originalSelector, (IMP)handleBackgroundEvents, "v@:@@@?")) {
      DDLogInfo(@"failed to add method(%@) for appdelegate", NSStringFromSelector(handleEventsForBackgroundURLSession));
    }
  }else {
    if (!class_addMethod(delegate, handleEventsForBackgroundURLSession, (IMP)handleBackgroundEvents, "v@:@@@?")) {
      DDLogInfo(@"failed to add method(%@) for appdelegate", NSStringFromSelector(handleEventsForBackgroundURLSession));
    }else {
      Method swizzledMethod = class_getInstanceMethod(delegate, handleEventsForBackgroundURLSession);
      method_exchangeImplementations(originalMethod, swizzledMethod);
    }
  }
  {
    NSString *dummyRequestUrlToWipeApplesAss = @"https://www.dummy.Request.Url.To.Wipe.Apples.Asses.com";
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:dummyRequestUrlToWipeApplesAss]];
    req.timeoutInterval = 365 * 24 * 3600; // a dummy request to work around [session getTasks... ] not callback
    [session dataTaskWithRequest:req];
  }
  [self addNotification];
  self->_session = session;
}

- (NSOperationQueue*)operationQueue {
  return self.session.delegateQueue;
}

- (void)dealloc {
  if (_downloadStatusManager) {
    [_downloadStatusManager closeDB];
  }
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setenableBackgroundMode:(BOOL)enableBackgroundMode {
  if (enableBackgroundMode && !_enableBackgroundMode) {
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
  } else if (!enableBackgroundMode && _enableBackgroundMode) {
    [self addNotification];
  }
  _enableBackgroundMode = enableBackgroundMode;
}

- (void)addNotification {
  [[NSNotificationCenter defaultCenter] addObserver:self
                                           selector:@selector(appEnterBackgroundNotification:)
                                               name:UIApplicationDidEnterBackgroundNotification
                                             object:nil];
}

- (void)appEnterBackgroundNotification:(NSNotification*)notification {
  if (self.bgTask != UIBackgroundTaskInvalid) {
#ifdef DEBUG
    NSLog(@"background notification seems to be called more than twice, ignore second one");
#endif
    return;
  }
#ifdef DEBUG
  NSLog(@"did enter background, pausing tasks");
#endif
  UIApplication *app = [UIApplication sharedApplication];
  dispatch_block_t finishBgTaskBlock = [^{
    if (self.bgTask != UIBackgroundTaskInvalid) {
      [app endBackgroundTask:self.bgTask];
      self.bgTask = UIBackgroundTaskInvalid;
    }
  } copy];
  self.bgTask = [app beginBackgroundTaskWithName:@"PauseDownloadsTask" expirationHandler:finishBgTaskBlock];
  [self pauseAllDownloadCompletion:finishBgTaskBlock];
}

///@brief must be called in the same queue as subsequence messaging
- (ZKDownloadRecord*)downloadStatusManager {
  if (!_downloadStatusManager) {
    _downloadStatusManager = [[ZKDownloadRecord alloc] init];
    [_downloadStatusManager
     openDB:[[self class] dbPath]
     onSuccess:^{
       DDLogInfo(@"db opened: %@", [[self class] dbPath]);
     }
     onFailure:^(NSError *error) {
       DDLogInfo(@"failed to open db: %@, error: %@", [[self class] dbPath], error);
     }];
  }
  return _downloadStatusManager;
}

- (void)download:(NSString *)remoteUrl
          sender:(id)sender
        onResume:(ResumeBlock)onResume
      onProgress:(ZKNetworkProgressBlock)onProgress
    onCompletion:(ZKNetworkCompletionBlock)onCompletion
      onRegister:(dispatch_block_t)onRegister {
  if (!remoteUrl) {
    NSAssert(NO, @"");
    if (onCompletion) {
      NSString *errMsg = @"无效输入";
      ZKNetworkDownloadStatus downloadStatus = ZKNetworkDownloadStatusError;
      dispatch_async(dispatch_get_main_queue(), ^{
        onCompletion(@{ZKNetworkErrorMsgKey:errMsg,
                       ZKNetworkDownloadStatusKey:@(downloadStatus)
                       },
                     @{ZKNetworkUrlKey:remoteUrl ?: [NSNull null]});
      });
    }
    return;
  }
  
  [self getTask:^(NSURLSessionDownloadTask *task) {
    void (^updateRecord)(ZKNetworkDownloadStatus status) = ^(ZKNetworkDownloadStatus status){
      [self setDownloadStatus:status errMsg:nil resumeData:nil url:remoteUrl];
    };
    if (sender) {
      [self registerDownloadCallbackRemote:remoteUrl
                                    sender:sender
                                  onResume:onResume
                                onProgress:onProgress
                              onCompletion:onCompletion
                                onRegister:onRegister];
    }

    dispatch_block_t startTaskBlock = ^{
      void (^startTask)(NSData *) = ^(NSData *resumeData){
        if (resumeData) {
          NSURLSessionTask *task = [self.session downloadTaskWithResumeData:resumeData];
          [task resume];
        } else {
          NSURL *url = [NSURL URLWithString:remoteUrl];
          NSURLSessionTask *task = [self.session downloadTaskWithURL:url];
          [task resume];
        }
        updateRecord(ZKNetworkDownloadStatusRunning);
      };
      [self.downloadStatusManager
       queryWithCriteria:@{@"url":@{@"value":remoteUrl}}
       callback:^(NSArray<NSDictionary *> *records) {
         NSDictionary *record = records.firstObject;
         if (record) {
           ZKNetworkDownloadStatus status =
           (ZKNetworkDownloadStatus)[(NSNumber*)record[@"status"] integerValue];
           NSData * resumeData = (NSData*)record[@"resume_data"];
           NSString *localPath = [[self class] localPathForUrl:remoteUrl];
           NSFileManager *fm = [NSFileManager defaultManager];
           if (status == ZKNetworkDownloadStatusCompleted && [fm fileExistsAtPath:localPath]) {
             [self notifyCompletion:remoteUrl errorInfo:nil];
           } else {
             startTask(resumeData);
           }
         }else {
           startTask(nil);
         }
       }];
    };
    if (task && (task.state == NSURLSessionTaskStateRunning || task.state == NSURLSessionTaskStateSuspended)) {
      [task resume];
      updateRecord(ZKNetworkDownloadStatusRunning);
    } else if(task.state == NSURLSessionTaskStateCanceling) {
      NSAssert(NO, @"eh... NSURLSessionTaskStateCanceling is middle state, since we are doing things in a single queue, this state should not be seen by us?");
    } else {
      startTaskBlock();
    }
  }
         forUrl:remoteUrl];
}

- (void)pauseAllDownloadCompletion:(dispatch_block_t)completion {
  [self allTask:^(NSArray<NSURLSessionDownloadTask *> *tasks) {
    if (!tasks.count) {
      [self.listeners removeAllObjects];
      if (completion) {
        dispatch_sync(dispatch_get_main_queue(), completion);
      }
      return;
    }
    NSMutableIndexSet *set = [NSMutableIndexSet indexSet];
    [tasks enumerateObjectsUsingBlock:^(NSURLSessionDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      [set addIndex:idx];
    }];
    [tasks enumerateObjectsUsingBlock:^(NSURLSessionDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      NSURL *url = obj.originalRequest.URL ?: obj.currentRequest.URL;
      [self pauseDownload:url.absoluteString callback:^{
        [set removeIndex:idx];
        if (set.count == 0) {
          [self.listeners removeAllObjects];
          if (completion) {
            dispatch_sync(dispatch_get_main_queue(), completion);
          }
        }
      }];
    }];
  }];
}

- (void)resumeAllPausedTasksCompletion:(dispatch_block_t)completion {
  dispatch_block_t theWork = ^{
    NSDictionary *criteria = @{@"status":@{@"value":@(ZKNetworkDownloadStatusPaused)}};
    [self.downloadStatusManager queryWithCriteria:@{} callback:^(NSArray<NSDictionary *> *records) {
      if (records.count == 0 && completion) {
        dispatch_async(dispatch_get_main_queue(), completion);
      }
      [records enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull rec, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *url = rec[@"url"];
        [self download:url
                sender:nil
              onResume:nil
            onProgress:nil
          onCompletion:nil
            onRegister:nil];
        if (idx == records.count - 1 && completion) {
          dispatch_async(dispatch_get_main_queue(), completion);
        }
      }];
    }];
  };
  [self.session.delegateQueue addOperationWithBlock:theWork];
}

- (void)registerDownloadCallbackRemote:(NSString*)remoteUrl
                                sender:(id)sender
                              onResume:(ResumeBlock)onResume
                            onProgress:(ZKNetworkProgressBlock)onProgress
                          onCompletion:(ZKNetworkCompletionBlock)onCompletion
                            onRegister:(dispatch_block_t)onRegister {
  NSNumber *senderKey = @((int)sender);
  NSMutableDictionary<NSString*, NSMutableDictionary*> *listeners =
  self.listeners[remoteUrl] ?: [NSMutableDictionary dictionary];
  self.listeners[remoteUrl] = listeners;
  
  NSMutableDictionary *progressBlocks =
  listeners[kZKNetworkProgressBlocksKey] ?: [NSMutableDictionary dictionary];
  listeners[kZKNetworkProgressBlocksKey] = progressBlocks;
  
  NSMutableDictionary *completionBlocks =
  listeners[kZKNetworkCompletionBlocksKey] ?: [NSMutableDictionary dictionary];
  listeners[kZKNetworkCompletionBlocksKey] = completionBlocks;
  
  if (onProgress) {
    progressBlocks[senderKey] = onProgress;
  }
  if (onCompletion) {
    completionBlocks[senderKey] = onCompletion;
  }
  if (onResume) {
    NSMutableDictionary *resumeBlocks =
    listeners[kResumeBlocksKey] ?: [NSMutableDictionary dictionary];
    listeners[kResumeBlocksKey] = resumeBlocks;
    resumeBlocks[senderKey] = onResume;
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    if (onRegister) {
      onRegister();
    }
  });

}

- (void)notifyProgress:(NSString*)url
          bytesWritten:(int64_t)written
            bytesTotal:(int64_t)total {
  NSParameterAssert(url);
  NSMutableDictionary<NSString*, NSMutableDictionary*> *listeners =
  self.listeners[url];
  if (!listeners) {
    return;
  }
  NSMutableDictionary *progressBlocks = listeners[kZKNetworkProgressBlocksKey];
  if (!progressBlocks) {
    return;
  }
  NSMutableDictionary *throttleInfo = listeners[kProgressThrottleInfoKey];
  int64_t beginTime = [throttleInfo[@"beginTime"] longLongValue];
  int64_t now = [NSDate timeIntervalSinceReferenceDate];
  
  if (now - beginTime > THROTTLE_SECONDS) {
#ifdef DEBUG
    NSLog(@"time up");
#endif
    if (!throttleInfo) {
      throttleInfo = [NSMutableDictionary dictionary];
      listeners[kProgressThrottleInfoKey] = throttleInfo;
    }
    throttleInfo[@"beginTime"] = @(now);
    [self callZKNetworkProgressBlocks:[progressBlocks allValues]
                         bytesWritten:written
                           bytesTotal:total];
  }else {
    throttleInfo[@"written"] = @(written);
    throttleInfo[@"total"] = @(total);
    if (!throttleInfo[@"delayedCall"]) {
      dispatch_block_t delayedCall = ^{
        [self.session.delegateQueue addOperationWithBlock:^{
          [throttleInfo removeObjectForKey:@"delayedCall"];
          int64_t now = [NSDate timeIntervalSinceReferenceDate];
          int64_t beginTime = [throttleInfo[@"beginTime"] longLongValue];
          int64_t savedWritten = [throttleInfo[@"written"] longLongValue];
          int64_t savedTotal = [throttleInfo[@"total"] longLongValue];
          if (now - beginTime > THROTTLE_SECONDS) {
#ifdef DEBUG
            NSLog(@"delayed call");
#endif
            [self callZKNetworkProgressBlocks:[progressBlocks allValues]
                                 bytesWritten:savedWritten
                                   bytesTotal:savedTotal];
            throttleInfo[@"beginTime"] = @(now);
          } else {
#ifdef DEBUG
            NSLog(@"delayed call stale");
#endif
          }
        }];
      };
      throttleInfo[@"delayedCall"] = delayedCall;
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(THROTTLE_SECONDS * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.session.delegateQueue addOperationWithBlock:delayedCall];
      });
    }
  }
}

- (void)callZKNetworkProgressBlocks:(NSArray<ZKNetworkProgressBlock> *)blocks
              bytesWritten:(int64_t)written
                bytesTotal:(int64_t)total {
  
  dispatch_async(dispatch_get_main_queue(), ^{
    [blocks enumerateObjectsUsingBlock:^(ZKNetworkProgressBlock  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
      //todo: calc remaining time
      obj(@{ZKNetworkDownloadedBytesKey:@(written), ZKNetworkTotalBytesKey:@(total)});
    }];
  });
}

- (void)notifyCompletion:(NSString*)url
               errorInfo:(NSDictionary*)errorInfo {
  
  NSParameterAssert(url);
  if (!url) return;
  
  NSMutableDictionary<NSString*, NSMutableDictionary*> *listeners =
  self.listeners[url];
  
  if (listeners[kZKNetworkProgressBlocksKey]) {
    [listeners removeObjectForKey:kZKNetworkProgressBlocksKey];
    [listeners removeObjectForKey:kProgressThrottleInfoKey];
  }
  
  NSMutableDictionary *completionBlocks = listeners[kZKNetworkCompletionBlocksKey];
  if (completionBlocks) {
    [listeners removeObjectForKey:kZKNetworkCompletionBlocksKey];
    dispatch_async(dispatch_get_main_queue(), ^{
      [completionBlocks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        ZKNetworkCompletionBlock completion = (ZKNetworkCompletionBlock)obj;
        completion(errorInfo, @{ZKNetworkUrlKey:url});
      }];
    });
    
  }
  
}

- (void)notifyResume:(NSString*)url {
  NSParameterAssert(url);
  if (!url) return;
  
  NSMutableDictionary<NSString*, NSMutableDictionary*> *listeners =
  self.listeners[url] ?: [NSMutableDictionary dictionary];
  
  NSDictionary *resumeBlocks = listeners[kResumeBlocksKey];
  [listeners removeObjectForKey:kResumeBlocksKey];
  dispatch_async(dispatch_get_main_queue(), ^{
    [resumeBlocks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
      ResumeBlock resumeBlock = (ResumeBlock)obj;
      resumeBlock(nil, @{ZKNetworkUrlKey:url});
    }];
  });
}

- (void)retrieveDownloadFileForUrl:(NSString*)remoteUrl
                  destinationPath:(NSString*)destPath
                        onSuccess:(dispatch_block_t)onSuccess
                        onFailure:(FailureCallback)onFailure {
  NSParameterAssert(remoteUrl);
  if (!remoteUrl) {
    if (onFailure) {
      onFailure([NSError errorWithDomain:@"" code:0 userInfo:@{@"msg":@"parameter invalid"}]);
    }
    return;
  }
  
  NSFileManager *fm = [NSFileManager defaultManager];
  NSError *error = nil;
  BOOL didMoveFile = NO;
  if (!(didMoveFile = [fm moveItemAtPath:[[self class] localPathForUrl:remoteUrl]
                                  toPath:destPath
                                   error:&error])) {
#ifdef DEBUG
    NSLog(@"failed to move move file, error: %@", error);
#endif
  }
  
  NSDictionary *criteria = @{@"url":@{@"value":remoteUrl}};
  if (didMoveFile) {
    [self.downloadStatusManager
     deleteCriteria:criteria
     onSuccess:^{
       DDLogInfo(@"did remove record for url: %@", remoteUrl);
       if (onSuccess) {
         onSuccess();
       }
     }
     onFailure:^(NSError *error) {
       DDLogInfo(@"failed to remove download record for url: %@, error: %@", remoteUrl, error);
       if (onFailure) {
         onFailure(error);
       }
     }];
  }else {
    // todo: more specific error, i.e. error message
    NSDictionary *update = @{@"status":@(ZKNetworkDownloadStatusError)};
    [self.downloadStatusManager
     update:update
     criteria:criteria
     onSuccess:^{
       DDLogInfo(@"did update");
       if (onFailure) {
         onFailure(error);
       }
     }
     onFailure:^(NSError *error) {
       DDLogInfo(@"failed to update: %@ criteria: %@, error: %@", update, criteria, error);
       if (onFailure) {
         onFailure(error);
       }
     }];
  }
}

- (void)setDownloadStatus:(ZKNetworkDownloadStatus)status
                   errMsg:(nullable NSString*)errMsg
               resumeData:(nullable NSData*)resumeData
                      url:(nonnull NSString*)url {
  NSDictionary *criteria = @{@"url":@{@"value":url}};
  NSMutableDictionary *updateInfo = [@{@"status":@(status)} mutableCopy];
  updateInfo[@"resume_data"] = resumeData ?: [NSNull null];
  updateInfo[@"err_msg"] = errMsg ?: [NSNull null];
  
  [self.downloadStatusManager
   queryWithCriteria:criteria
   callback:^(NSArray<NSDictionary *> *results) {
     if (results.count) {
       [self.downloadStatusManager
        update:updateInfo
        criteria:criteria
        onSuccess:^{
          DDLogInfo(@"did update download status: %@, for url: %@", @(status), url);
        }
        onFailure:^(NSError *error) {
          DDLogInfo(@"failed to update download status: %@, for url: %@, error: %@", @(status), url, error);
        }];
     }else {
       NSArray *records = @[@{@"url":url, @"status":@(status), @"start_time":@(round([NSDate timeIntervalSinceReferenceDate]))}];
       [self.downloadStatusManager
        insert:records
        onSuccess:^{
          DDLogInfo(@"did insert download record for url: %@, records: %@", url, records);
        }
        onFailure:^(NSError *error) {
          DDLogInfo(@"failed to insert record for url: %@, records: %@, error: %@", url, records, error);
        }];
     }
   }];
  
}

- (void)removeListenerSender:(id)sender {
  [self.session.delegateQueue addOperationWithBlock:^{
    [self.listeners
     enumerateKeysAndObjectsUsingBlock:
     ^(NSString * _Nonnull key,
       NSMutableDictionary<NSString *,NSMutableDictionary *> * _Nonnull obj,
       BOOL * _Nonnull stop) {
       NSMutableDictionary *onResumeBlocks = obj[kResumeBlocksKey];
       [onResumeBlocks removeObjectForKey:@((int)sender)];
       NSMutableDictionary *progressBlocks = obj[kZKNetworkProgressBlocksKey];
       [progressBlocks removeObjectForKey:@((int)sender)];
       NSMutableDictionary *completionBlocks = obj[kZKNetworkCompletionBlocksKey];
       [completionBlocks removeObjectForKey:@((int)sender)];
    }];
  }];
}

- (void)cancelDownload:(NSString *)remoteUrl
              callback:(dispatch_block_t)onCompletion {
  if (!remoteUrl) {
    NSAssert(remoteUrl, @"");
    if (onCompletion) {
      onCompletion();
    }
    return;
  }
  
  [self getTask:
   ^(NSURLSessionDownloadTask *task) {
     NSString *url = task.originalRequest.URL.absoluteString ?: task.currentRequest.URL.absoluteString;
     NSAssert(url, @"");
     [task cancel];
     if (onCompletion) {
       dispatch_async(dispatch_get_main_queue(), onCompletion);
     }
   }
         forUrl:remoteUrl];
}

- (void)pauseDownload:(NSString *)remoteUrl
             callback:(dispatch_block_t)onCompletion {
  if (!remoteUrl) {
    NSAssert(remoteUrl, @"");
    if (onCompletion) {
      dispatch_async(dispatch_get_main_queue(), onCompletion);
    }
    return;
  }
  
  [self getTask:^(NSURLSessionDownloadTask *task) {
    if (!task) {
      if (onCompletion) {
        onCompletion();
      }
      return;
    }
    [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
      NSLog(@"paused task: %@, has resumeData: %@", remoteUrl, resumeData ? @"YES": @"NO");
      [self.session.delegateQueue addOperationWithBlock:^{
        [self setDownloadStatus:ZKNetworkDownloadStatusPaused
                         errMsg:NULL
                     resumeData:resumeData
                            url:remoteUrl];
        if (onCompletion) {
          dispatch_async(dispatch_get_main_queue(), onCompletion);
        }
      }];
    }];
  }
         forUrl:remoteUrl];
  
}

- (void)getTask:(void(^)(NSURLSessionDownloadTask *task))handleTask
         forUrl:(NSString*)remoteUrl {
  [self.session getTasksWithCompletionHandler:
   ^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks,
     NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks,
     NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
     if (downloadTasks.count == 0) {
       handleTask(nil);
     } else {
       [downloadTasks enumerateObjectsUsingBlock:
        ^(NSURLSessionDownloadTask * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
          NSString *url = obj.originalRequest.URL.absoluteString ?: obj.currentRequest.URL.absoluteString;
          NSAssert(url, @"");
          if ([url isEqualToString:remoteUrl]) {
            handleTask(obj);
            *stop = YES;
          }else {
            if (idx == downloadTasks.count - 1) {
              handleTask(nil);
            }
          }
        }];
     }
  }];
}

#pragma mark -- session and download delegate
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
  if (self.onDidHandleBackgroundSessionEvents) {
    self.onDidHandleBackgroundSessionEvents();
  }
  self.onDidHandleBackgroundSessionEvents = nil;
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
 didResumeAtOffset:(int64_t)fileOffset
expectedTotalBytes:(int64_t)expectedTotalBytes {
  [self notifyResume:
   downloadTask.originalRequest.URL.absoluteString ?: downloadTask.currentRequest.URL.absoluteString];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
  totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
  [self notifyProgress:downloadTask.originalRequest.URL.absoluteString ?: downloadTask.currentRequest.URL.absoluteString
          bytesWritten:totalBytesWritten
            bytesTotal:totalBytesExpectedToWrite];
}

- (void)URLSession:(NSURLSession *)session
      downloadTask:(NSURLSessionDownloadTask *)downloadTask
  didFinishDownloadingToURL:(NSURL *)location {
  NSString *url = downloadTask.originalRequest.URL.absoluteString ?: downloadTask.currentRequest.URL.absoluteString;
  NSAssert(url, @"");
  if (!url) {
    // todo: not supposed to happen, but can we handle it in a better way
    return;
  }
  NSString *localPath = [self.class localPathForUrl:url];
  NSURL *localPathUrl = [NSURL fileURLWithPath:localPath];
  
  NSFileManager *fm = [NSFileManager defaultManager];
  NSURL *dirPath = [localPathUrl URLByDeletingLastPathComponent];
  [fm createDirectoryAtURL:dirPath withIntermediateDirectories:YES attributes:nil error:NULL];
  NSError *error = nil;
  if (![fm moveItemAtURL:location
                   toURL:localPathUrl
                   error:&error]) {
    [self setDownloadStatus:ZKNetworkDownloadStatusError errMsg:[self errorMsg:error] resumeData:nil url:url];
    [self notifyCompletion:url
                 errorInfo:@{
                             ZKNetworkDownloadStatusKey:@(ZKNetworkDownloadStatusError),
                             ZKNetworkErrorMsgKey:[self errorMsg:error] ?: @"",
                             ZKNetworkLocalErrorKey:error ?: [NSNull null],
                             }];
    DDLogInfo(@"failed to move file: %@ to: %@, error: %@", location, localPathUrl, error);
    NSString *tmpPath = [NSString stringWithFormat:@"%s", [location fileSystemRepresentation]];
    if ([fm fileExistsAtPath:tmpPath]) {
      DDLogInfo(@"source file does exist, %@", tmpPath);
    } else {
      DDLogInfo(@"source file doesnot exist, %@", tmpPath);
    }
  }else {
#ifdef DEBUG
    DDLogInfo(@"did download file to path: %@", localPathUrl);
#endif
    [self setDownloadStatus:ZKNetworkDownloadStatusCompleted errMsg:nil resumeData:nil url:url];
    [self notifyCompletion:url errorInfo:nil];
  }
}

- (NSString*)errorMsg:(NSError*)error {
  return [NSString stringWithFormat:@"code: %ld, msg: %@", error.code, error.localizedDescription];
}

- (void)URLSession:(NSURLSession *)session
              task:(NSURLSessionTask *)task
didCompleteWithError:(NSError *)error {
  if (![task isKindOfClass:NSURLSessionDownloadTask.class]) {
#ifdef DEBUG
    NSLog(@"task of different type than download completed, %@, error: %@", task, error);
#endif
    return;
  }
  NSURLSessionDownloadTask *downloadTask = (NSURLSessionDownloadTask*)task;
  NSString *url = downloadTask.originalRequest.URL.absoluteString ?: downloadTask.currentRequest.URL.absoluteString;
  if (!url) {
    return;
  }
  NSData *resumeData = error.userInfo[NSURLSessionDownloadTaskResumeData];
  if (error && error.code != NSURLErrorCancelled) { // for cancelled tasks, resumeData has alread been collected and status set properly
    [self setDownloadStatus:ZKNetworkDownloadStatusPaused
                     errMsg:nil
                 resumeData:resumeData
                        url:url];
    [self notifyCompletion:url
                 errorInfo:@{ZKNetworkDownloadStatusKey:@(ZKNetworkDownloadStatusPaused),
                             ZKNetworkErrorMsgKey:[self errorMsg:error],
                             }];
  }else {
    //nop, because already handled inURLSession:downloadTask:didFinishDownloadingToURL
  }
  
}

#pragma mark -- query download state

- (NSDictionary*)downloadRecordsForUrls:(NSArray<NSString *> *)urls {
  if (!urls.count) {
    NSAssert(NO, @"input invalid");
    return nil;
  }
  NSMutableDictionary *ret = [NSMutableDictionary dictionary];
  [urls enumerateObjectsUsingBlock:^(NSString * _Nonnull url, NSUInteger idx, BOOL * _Nonnull stop) {
    [self.downloadStatusManager
     queryWithCriteria:@{@"url":@{@"value":url}}
     callback:^(NSArray<NSDictionary *> *records) {
       if (records.lastObject) {
         ret[url] = records.lastObject;
       }
     }];
  }];
  return ret;
}
#ifdef DEBUG

- (void)getRecords:(void(^)(NSArray<NSDictionary*> *))callback {
  [self.downloadStatusManager query:callback];
}

- (void)getDownloadedFiles:(void(^)(NSArray<NSDictionary*>*))filesCallback {
  NSMutableArray *ret = [NSMutableArray array];
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *root = [[self class] downloadPath];
  NSDirectoryEnumerator *dirEnum = [fm enumeratorAtPath:root];
  NSString *file;
  while ((file = [dirEnum nextObject])) {
    NSString *path = [NSString stringWithFormat:@"%@/%@", root, file];
    BOOL isDir;
    if ([fm fileExistsAtPath:path isDirectory:&isDir] && !isDir) {
      NSDictionary *attr = [fm fileAttributesAtPath:path traverseLink:NO];
      [ret addObject:@{
                       @"file": path,
                       @"attributes": attr ?: @{}}];
    }
  }
  if (filesCallback) {
    filesCallback(ret);
  }
}
#endif

- (void)allTask:(void(^)(NSArray<NSURLSessionDownloadTask*> *))handleTasks {
  [self.session getTasksWithCompletionHandler:
   ^(NSArray<NSURLSessionDataTask *> * _Nonnull dataTasks,
     NSArray<NSURLSessionUploadTask *> * _Nonnull uploadTasks,
     NSArray<NSURLSessionDownloadTask *> * _Nonnull downloadTasks) {
     if (handleTasks) {
       handleTasks(downloadTasks);
     }
   }];
}

#pragma mark -- file utils
+ (NSString*)localPathForUrl:(NSString*)remoteUrl {
  return [self localPathForUrl:remoteUrl subdir:nil];
}

+ (NSString*)localPathForUrl:(NSString*)remoteUrl subdir:(NSString *)subdir {
  NSString *cacheRootDefault = [self downloadPath];
  NSString *cacheSubdir = subdir ? [cacheRootDefault stringByAppendingPathComponent:subdir] : cacheRootDefault;
  NSMutableString *ret = [NSMutableString stringWithString:cacheSubdir];
  
  NSError *error = nil;
  if (![[NSFileManager defaultManager]
        createDirectoryAtPath:ret
        withIntermediateDirectories:YES
        attributes:nil
        error:&error]) {
    
    if (error.code != NSFileWriteFileExistsError) {
      DDLogInfo(@"failed to create dir: %@, error: %@", ret, error);
    }
  }
  
  if (remoteUrl) {
    [ret appendFormat:@"%@", [self encodeRemoteUrlToLocalPath:remoteUrl]];
  }

  return ret;
}

+ (NSString*)encodeRemoteUrlToLocalPath:(NSString*)urlStr {
  NSMutableString *ret = [NSMutableString stringWithString:@""];
  NSURL *url = urlStr ? [NSURL URLWithString:urlStr] : nil;
  if (url.scheme) {
    NSString *lastChar = ret.length ? [ret substringFromIndex:ret.length - 1] : nil;
    if ([lastChar isEqualToString:@"/"]) {
      [ret appendFormat:@"%@", url.scheme];
    } else {
      [ret appendFormat:@"/%@", url.scheme];
    }
  }
  
  if (url.host) {
    [ret appendFormat:@"/%@", url.host];
  }
  if (url.port) {
    [ret appendFormat:@"/%@", url.port];
  }
  
  if (url.user || url.password) {
    [ret appendFormat:@"/%@-%@", url.user, url.password];
  }
  
  if (url.parameterString) {
    [ret appendFormat:@"/%@", url.parameterString];
  }
  
  if (url.query) {
    NSDictionary<NSString*, NSString*> *queryParams = [url.query URLQueryParameters];
    [queryParams
     enumerateKeysAndObjectsUsingBlock:
     ^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
       
       [ret appendFormat:@"/%@-%@", key, obj];
     }];
  }
  
  if (url.fragment) {
    [ret appendFormat:@"/%@", url.fragment];
  }
  
  NSString *lastChar = ret.length ? [ret substringFromIndex:ret.length - 1] : nil;
  if ([lastChar isEqualToString:@"/"]) {
    NSRange rg;
    rg.location = ret.length - 1;
    rg.length = 1;
    [ret deleteCharactersInRange:rg];
  }
  if (url.path) {
    [ret appendFormat:@"%@", url.path];
  }

  return ret;
}

+ (NSString*)dbPath {
  NSString *databaseDir = [[self rootPath] stringByAppendingPathComponent:@"Database"];
  NSFileManager *fm = [NSFileManager defaultManager];
  
  if (![fm fileExistsAtPath:databaseDir]) {
    NSError *error = nil;
    if (![fm createDirectoryAtPath:databaseDir withIntermediateDirectories:YES attributes:nil error:&error]) {
      DDLogInfo(@"failed to create download roort directory: %@, error: %@", databaseDir, error);
    }
  }
  return [databaseDir stringByAppendingPathComponent:@"download.sqlite"];
}

+ (NSString*)downloadPath {
  NSString *downloadDir = [[self rootPath] stringByAppendingPathComponent:@"Download"];
  
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:downloadDir]) {
    NSError *error = nil;
    if (![fm createDirectoryAtPath:downloadDir withIntermediateDirectories:YES attributes:nil error:&error]) {
      DDLogInfo(@"failed to create download roort directory: %@, error: %@", downloadDir, error);
    }
  }
  return downloadDir;
}

+ (NSString*)rootPath {
  NSArray<NSString*> *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSAssert(dirs.count, @"");
  NSString *bundleName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
  NSAssert(bundleName, @"");
  
  NSString *ret = [NSString stringWithFormat:@"%@/%@/DownloadRoot", dirs[0], bundleName];
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:ret]) {
    NSError *error = nil;
    if (![fm createDirectoryAtPath:ret withIntermediateDirectories:YES attributes:nil error:&error]) {
      DDLogInfo(@"failed to create download roort directory: %@, error: %@", ret, error);
    }
#ifdef DEBUG
    NSLog(@"cache path: %@", ret);
#endif
  }
  return ret;
}

@end

