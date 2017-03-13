//
//  OpenLogJsonKit.h
//  OpenLog
//
//  Created by bellchen on 2017/3/8.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (OpenLogJson)
- (NSString*)jsonString;
@end

@interface NSString (OpenLogJson)
- (id)objectFromJson;
@end

@interface NSData (OpenLogJson)
- (id)objectFromJson;
@end
