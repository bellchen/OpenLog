//
//  OpenLogJsonKit.m
//  OpenLog
//
//  Created by bellchen on 2017/3/8.
//  Copyright © 2017年 wentiertong.com. All rights reserved.
//

#import "OpenLogJsonKit.h"

@implementation NSObject (OpenLogJson)

- (NSString*)jsonString{
    NSError *error;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:&error];
    if (jsonData) {
         return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    }else{
        return nil;
    }
}
@end

@implementation NSString (OpenLogJson)

- (id)objectFromJson{
    NSData *jsonData = [self dataUsingEncoding:NSUTF8StringEncoding];
    return [jsonData objectFromJson];
}

@end

@implementation NSData (OpenLogJson)

- (id)objectFromJson{
    NSError *error;
    id outData = [NSJSONSerialization JSONObjectWithData:self options:NSJSONReadingMutableContainers error:&error];
    if(!error){
        return outData;
    }
    return nil;
}

@end
