//
//  OpenLogAES128.h
//  OpenLog
//
//  Created by bellchen on 2017/3/14.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (AES128)
- (NSString*)encryptWithKey:(NSString*)key;
- (NSString*)decryptWithKey:(NSString*)key;
@end

@interface NSData (AES128)
- (NSData*)encryptWithKey:(NSString*)key;
- (NSData*)decryptWithKey:(NSString*)key;
@end
