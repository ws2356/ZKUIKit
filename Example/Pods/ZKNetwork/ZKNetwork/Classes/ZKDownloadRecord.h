//
//  ZKDownloadRecord.h
//  SmartStudy
//
//  Created by wansong on 7/24/16.
//  Copyright © 2016 Innobuddy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^FailureCallback)(NSError *);
typedef void (^QueryCallback) (NSArray<NSDictionary*> *);

@interface ZKDownloadRecord : NSObject

- (void)openDB:(NSString*)path
     onSuccess:(dispatch_block_t)onSuccess
     onFailure:(FailureCallback)onFailure;

- (void)closeDB;

- (void)insert:(NSArray<NSDictionary*> *)records
     onSuccess:(dispatch_block_t)onSuccess
       onFailure:(FailureCallback)onFailure;

- (void)update:(NSArray<NSDictionary*> *)updates
     criterias:(NSArray<NSDictionary*> *)criterias
     onSuccess:(dispatch_block_t)onSuccess
     onFailure:(FailureCallback)onFailure;

- (void)update:(NSDictionary*)keyValues
      criteria:(NSDictionary*)criteria
     onSuccess:(dispatch_block_t)onSuccess
       onFailure:(FailureCallback)onFailure;

- (void)deleteCriteria:(NSDictionary *)criteria
     onSuccess:(dispatch_block_t)onSuccess
             onFailure:(FailureCallback)onFailure;
  
  
- (void)query:(QueryCallback)callback;
- (void)queryWithCriteria:(NSDictionary*)criteria callback:(QueryCallback)callback;

@end
