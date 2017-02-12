//
//  ZKDownloadRecord.m
//  SmartStudy
//
//  Created by wansong on 7/24/16.
//  Copyright © 2016 Innobuddy Inc. All rights reserved.
//

#import "ZKDownloadRecord.h"
#import "FMDB.h"
#import "ZKNetwork.h"

@interface ZKDownloadRecord ()
@property (strong, nonatomic) FMDatabase *db;
@end

@implementation ZKDownloadRecord

+ (NSArray<NSString*> *)fields {
  return @[@"url", @"status", @"start_time"];
}

- (void)openDB:(NSString *)path
     onSuccess:(dispatch_block_t)onSuccess
     onFailure:(FailureCallback)onFailure {
  if (!path) {
    NSAssert(NO, @"invalid path!");
    if (onFailure) {
      onFailure(nil);
    }
    return;
  }
  
  NSAssert(!self.db, @"");
  self.db = [FMDatabase databaseWithPath:path];
#ifdef DEBUG
//  self.db.traceExecution = YES;
#endif
  if (!self.db) {
    NSAssert(NO, @"failed to open db at: %@", path);
    if (onFailure) {
      onFailure(nil);
    }
    return;
  }
  
  if (![self.db open]) {
    NSLog(@"failed to open database: %@, error: %@", path, self.db.lastError);
    if (onFailure) {
      onFailure(self.db.lastError);
    }
    return;
  }
  
  NSString *createIfNeeded =
  @"CREATE TABLE IF NOT EXISTS download_record(url PRIMARY KEY CHECK(url NOT NULL AND length(url) > 11), status INTEGER NOT NULL, err_msg TEXT, start_time INTEGER NOT NULL, resume_data BLOB);";
  if ([self.db executeUpdate:createIfNeeded]) {
    if (onSuccess) {
      onSuccess();
    }
  }else {
    if (onFailure) {
      onFailure(self.db.lastError);
    }
  }
  
}

- (void)closeDB {
  NSAssert(self.db, @"");
  [self.db close];
  self.db = nil;
}

- (void)query:(QueryCallback)callback {
  [self queryWithCriteria:nil callback:callback];
}

/**
 @param criteria {key, value, relation} where relation can be @"<", @">", @"==" etc if no relation default to @"=="
 @param callback all queried objects with field name as key
 */
- (void)queryWithCriteria:(NSDictionary*)criteria callback:(QueryCallback)callback {
  NSAssert(self.db, @"");
  NSString *mainSql = @"SELECT * FROM download_record ";
  NSArray *allKeys = [criteria allKeys];
  NSString *where = [[[self class] buildWhereClause:allKeys conditions:criteria] stringByAppendingString:@";"];
  NSArray *allValues = [criteria objectsForKeys:allKeys notFoundMarker:[NSNull null]];
  NSMutableArray *ret = [NSMutableArray array];
  NSString *fullSql = [NSString stringWithFormat:@"%@ %@", mainSql, where];
  
  //todo: order by, make the result more predictable
  
  FMResultSet *results =
  [self.db executeQuery:fullSql
   withArgumentsInArray:[allValues valueForKey:@"value"]];
  if (!results) {
    NSLog(@"failed to query sql(%@), no result", fullSql);
    if (callback) {
      callback(nil);
    }
    return;
  }
  
  //todo: wansong, more automation
  int coln = [results columnCount];
  while ([results next]) {
    NSMutableDictionary *item = [NSMutableDictionary dictionary];
    NSString *key = nil;
    id value = nil;
    
    if (coln > 0) {
      key = [results columnNameForIndex:0];
      value = [results stringForColumnIndex:0];
      item[key] = value;
    }
    if (coln > 1) {
      key = [results columnNameForIndex:1];
      value = @([results intForColumnIndex:1]);
      item[key] = value;
    }
    if (coln > 2) {
      key = [results columnNameForIndex:2];
      value = [results stringForColumnIndex:2];
      item[key] = value;
    }
    if (coln > 3) {
      key = [results columnNameForIndex:3];
      value = @([results intForColumnIndex:3]);
      item[key] = value;
    }
    if (coln > 4) {
      key = [results columnNameForIndex:4];
      value = [results dataForColumnIndex:4];
      item[key] = value;
    }
    [ret addObject:item];
  }
  if (callback) {
    callback(ret);
  }
}

+ (NSString*)buildWhereClause:(NSArray*)keys conditions:(NSDictionary*)conditions {
  if (!keys.count) {
    return @"";
  }
  
  NSMutableString *ret = [NSMutableString stringWithString:@" where "];
  
  [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    NSString *aKey = (NSString*)obj;
    NSString *relation = (NSString*)conditions[aKey][@"relation"];
    if (!relation) {
      relation = @"==";
    }
    
    [ret appendFormat:@"%@ %@ ?", aKey, relation];
  }];
  
  return ret;
}

- (void)insert:(NSArray<NSDictionary *> *)records
     onSuccess:(dispatch_block_t)onSuccess
       onFailure:(FailureCallback)onFailure {
  
  if (!records.count) {
    if (onSuccess) {
      onSuccess();
    }
    return;
  }
  
  [self.db beginTransaction];
  [records enumerateObjectsUsingBlock:^(NSDictionary * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    NSArray *values = @[obj[@"url"], obj[@"status"], obj[@"err_msg"] ?: [NSNull null], obj[@"start_time"], obj[@"resume_data"] ?: [NSNull null]];
    NSError *error = nil;
    NSString *fullSql = @"INSERT INTO download_record (url, status, err_msg, start_time, resume_data) VALUES(?, ?, ?, ?, ?)";
    
    if (![self.db executeUpdate:fullSql values:values error:&error]) {
      NSLog(@"failed to insert item: %@, sql: %@ error: %@, will rollback", obj, fullSql, error);
      if (onFailure) {
        onFailure(error);
      }
      if (![self.db rollback]) {
        NSLog(@"failed to rollback after insert failed");
      }
      *stop = YES;
    }else {
      if (idx == records.count - 1) {
        if ([self.db commit]) {
          if (onSuccess) {
            onSuccess();
          }
        }else {
          NSLog(@"failed to commit after inserts, error: %@", self.db.lastError);
          if (onFailure) {
            onFailure(self.db.lastError);
          }
        }
      }
    }
  }];
}

- (void)update:(NSDictionary *)keyValues
      criteria:(NSDictionary *)criteria
     onSuccess:(dispatch_block_t)onSuccess
       onFailure:(FailureCallback)onFailure {
  
  NSString *mainSql = @"UPDATE download_record ";
  NSArray *colKeys = [keyValues allKeys];
  NSString *set = [[self class] buildUpdateSetClause:colKeys];
  
  NSArray *whereKeys = [criteria allKeys];
  NSString *where = [[self class] buildWhereClause:whereKeys conditions:criteria];
  
  NSMutableArray *values =
  [NSMutableArray arrayWithArray:
   [keyValues objectsForKeys:colKeys notFoundMarker:[NSNull null]]
   ];
  [values addObjectsFromArray:
   [[criteria objectsForKeys:whereKeys notFoundMarker:[NSNull null]] valueForKey:@"value"]];
  
  NSString *fullSql =
  [NSString stringWithFormat:@"%@ %@ %@;", mainSql, set, where];
  
  NSError *error = nil;
  if (![self.db executeUpdate:fullSql values:values error:&error]) {
    NSLog(@"failed to execute sql(%@), error: %@", fullSql, error);
    if (onFailure) {
      onFailure(error);
    }
    
  }else {
    NSLog(@"did execute update sql(%@), binding values(%@), error: %@", fullSql, values, self.db.lastError);
    if(onSuccess) {
      onSuccess();
    }
  }
  
}

- (void)update:(NSArray<NSDictionary*> *)updates
     criterias:(NSArray<NSDictionary*> *)criterias
     onSuccess:(dispatch_block_t)onSuccess
     onFailure:(FailureCallback)onFailure {
  
  NSAssert(updates.count == criterias.count, @"invalid input");
  NSAssert(updates.count > 0, @"invalid input");
  
  [self.db beginTransaction];
  for (NSUInteger i = 0; i < updates.count; i++) {
    NSDictionary *update = updates[i];
    NSDictionary *criteria = criterias[i];
    
    BOOL __block shouldQuit = NO;
    [self update:update
        criteria:criteria
       onSuccess:^{
         if (i == updates.count - 1) {
           
           if (![self.db commit]) {
             NSLog(@"failed to commit a transaction");
             if (onSuccess) {
               onSuccess();
             }
           }else {
             if (onFailure) {
               onFailure(self.db.lastError);
             }
           }
         }
       }
       onFailure:^(NSError *error) {
         shouldQuit = YES;
         NSLog(@"failed to update(%@) with criteria(%@), error: %@", update, criteria, error);
         if (![self.db rollback]) {
           NSLog(@"failed to rollback, error: %@", self.db.lastError);
         }
         if (onFailure) {
           onFailure(self.db.lastError);
         }
       }];
    
    if (shouldQuit) {
      break;
    }
  }
}

- (void)deleteCriteria:(NSDictionary *)criteria
     onSuccess:(dispatch_block_t)onSuccess
     onFailure:(FailureCallback)onFailure {
  NSArray *whereKeys = [criteria allKeys];
  NSString *where = [[self class] buildWhereClause:whereKeys conditions:criteria];
  NSString *sql = [NSString stringWithFormat:@"DELETE FROM download_record %@;", where];
  NSArray *values = [criteria objectsForKeys:whereKeys notFoundMarker:[NSNull null]];
  
  NSError *error = nil;
  if (![self.db executeUpdate:sql values:[values valueForKey:@"value"] error:&error]) {
    if (onFailure) {
      onFailure(error);
    }
  }else {
    if (onSuccess) {
      onSuccess();
    }
  }
  
}

+ (NSString*)buildUpdateSetClause:(NSArray*)keys {
  NSMutableString *ret = [NSMutableString stringWithString:@" SET "];
  
  [keys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
    NSString *col_name = (NSString*)obj;
    if (idx == 0) {
      [ret appendFormat:@"%@ = ? ", col_name];
    }else {
      [ret appendFormat:@", %@ = ? ", col_name];
    }
  }];
  return ret;
}

@end
