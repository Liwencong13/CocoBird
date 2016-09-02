//
//  NSObject+STKVO.h
//  STKVODemo
//
//  Created by MacBook on 16/8/24.
//  Copyright © 2016年 Macbook. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSObject (STKVO)

- (void)st_addObserver:(NSObject *)observer forKey:(NSString *)key selector:(SEL)selector;

- (void)st_removeObserver:(NSObject *)observer forKey:(NSString *)key;

@end
