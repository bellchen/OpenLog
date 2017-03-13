//
//  OpenLogUDID.h
//  OpenLog
//
//  Created by bellchen on 2017/3/8.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OpenLogUDID : NSObject
+ (NSString*)value;
+ (NSString*)valueWithError:(NSError**)error;
+ (void)setOptOut:(BOOL)optOutValue;
@end
