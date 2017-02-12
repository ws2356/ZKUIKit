//
//  TableViewCell.h
//  ServerInApp
//
//  Created by wansong.mbp.work on 04/02/2017.
//  Copyright © 2017 zhike. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "ZKVideoView.h"

@interface TableViewCell : UITableViewCell
@property (readonly, nonatomic) ZKVideoView *videoView;
@property (copy, nonatomic) NSDictionary *videoInfo;
@end
