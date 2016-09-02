//
//  NSObject+STKVO.m
//  STKVODemo
//
//  Created by MacBook on 16/8/24.
//  Copyright © 2016年 Macbook. All rights reserved.
//

#import "NSObject+STKVO.h"
#import <objc/runtime.h>
#import <objc/message.h>

NSString *const kSTKVOClassPrefix = @"STKVOClass_";
NSString *const kSTKVOAssociatedObservers = @"STKVOAssociatedObservers";

@interface STObservationInfo : NSObject
@property (nonatomic, weak) NSObject *observer;
@property (nonatomic, copy) NSString *key;
@property (nonatomic, assign) SEL selector;
@end

@implementation STObservationInfo

- (instancetype)initWithObserver:(NSObject *)observer key:(NSString *)key selector:(SEL)selector
{
    self = [super init];
    if (self) {
        _observer = observer;
        _key = key;
        _selector = selector;
    }
    return self;
}

@end

@implementation NSObject (STKVO)

#pragma mark - public method

- (void)st_addObserver:(NSObject *)observer forKey:(NSString *)key selector:(SEL)selector
{
    SEL setterSelector = NSSelectorFromString([self getSetterWithKey:key]);     // 拿到属性的 setter 方法名
    Method setterMethod = class_getInstanceMethod(self.class, setterSelector);  // 拿到属性的 setter 方法
    if (!setterMethod) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"cant find setter for the key" userInfo:nil];
        return;
    }
    
    Class kvoClass = object_getClass(self);
    NSString *className = NSStringFromClass(kvoClass);
    if (![className hasPrefix:kSTKVOClassPrefix]) {               // 不是 KVO 类
        kvoClass = [self createKVOClassWithClassName:className]; // 创建 KVO 类
    }
    
    if (![self hasOverriddenSelector:setterSelector]) { // 没有重写 setter
        const char *types = method_getTypeEncoding(setterMethod);
        class_addMethod(kvoClass, setterSelector, (IMP)kvo_setter, types); // 修改 setter 方法的实现
    }
    
    // 添加观察者
    STObservationInfo *info = [[STObservationInfo alloc]initWithObserver:observer key:key selector:selector];
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kSTKVOAssociatedObservers));
    if (!observers) {
        observers = [NSMutableArray array];
        objc_setAssociatedObject(self, (__bridge const void *)(kSTKVOAssociatedObservers), observers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [observers addObject:info];
}

- (void)st_removeObserver:(NSObject *)observer forKey:(NSString *)key
{
    NSMutableArray* observers = objc_getAssociatedObject(self, (__bridge const void *)(kSTKVOAssociatedObservers));
    
    STObservationInfo *infoToRemove;
    for (STObservationInfo* info in observers) { // 只移除一个 Observer
        if (info.observer == observer && [info.key isEqualToString:key]) {
            infoToRemove = info;
            break;
        }
    }
    
    [observers removeObject:infoToRemove];
}

#pragma mark - private method
// 拼接 setter 字符串
- (NSString *)getSetterWithKey:(NSString *)key
{
    if (key.length == 0) {
        return nil;
    }
    
    NSString *firstCharacter = [key substringWithRange:NSMakeRange(0, 1)].uppercaseString; // 首字母大写
    NSString *otherCharacters = [key substringFromIndex:1];
    return [NSString stringWithFormat:@"set%@%@:", firstCharacter, otherCharacters];
}

// 通过 setter 获得 getter
- (NSString *)getterWithSetterName:(NSString *)setter
{
    if (setter.length == 0 || ![setter hasPrefix:@"set"] || ![setter hasSuffix:@":"]) {
        return nil;
    }
    
    NSString *getter = [setter substringWithRange:NSMakeRange(3, setter.length - 4)];
    NSString *firstCharacter = [getter substringToIndex:1].lowercaseString;  // 首字母小写
    return [getter stringByReplacingCharactersInRange:NSMakeRange(0, 1) withString:firstCharacter];
}

// 运行时创建一个继承自当前类的子类 称为 KVO 类
- (Class)createKVOClassWithClassName:(NSString *)className
{
    NSString *kvoClassName = [kSTKVOClassPrefix stringByAppendingString:className];
    Class kvoClass = NSClassFromString(kvoClassName);
    
    if (kvoClass) { // 已经有了
        return kvoClass;
    }
    
    kvoClass = objc_allocateClassPair(object_getClass(self), kvoClassName.UTF8String, 0); // 创建一个继承自当前类的子类
    
    Method classMethod = class_getInstanceMethod(object_getClass(self), @selector(class));
    const char *types = method_getTypeEncoding(classMethod);
    class_addMethod(kvoClass, @selector(class), (IMP)kvo_class, types); // 修改 class 方法的实现
    
    object_setClass(self, kvoClass); // 让 isa 指向 KVOClass
    
    objc_registerClassPair(kvoClass); // remember this
    
    return kvoClass;
}

// 检测是否重写了 setter 方法
- (BOOL)hasOverriddenSelector:(SEL)selector
{
    Class kvoClass = object_getClass(self); // 代码执行到这里 已经修改了isa指针
    unsigned int methodCount = 0;
    Method *methodList = class_copyMethodList(kvoClass, &methodCount); // 获取方法列表
//    NSLog(@"%i", methodCount);
    for (unsigned int i = 0; i < methodCount; i++) {
        if (method_getName(methodList[i]) == selector) {
            free(methodList);
            return YES;
        }
    }
    free(methodList);
    return NO;
}

#pragma mark - overrided method
// 重写的 class 方法 返回当前类的父类
static Class kvo_class(id self, SEL _cmd)
{
    return class_getSuperclass(object_getClass(self));
}

// 重写的 setter 方法
static void kvo_setter(id self, SEL _cmd, id newValue)
{
    NSString *getterName = [self getterWithSetterName:NSStringFromSelector(_cmd)]; // _cmd 代表当前方法

    if (!getterName) {
        @throw [NSException exceptionWithName:NSInvalidArgumentException reason:@"cant find setter for property" userInfo:nil];
        return;
    }
    
    // 调用原来的 setter
    struct objc_super superclass = {
        .receiver = self,
        .super_class = class_getSuperclass(object_getClass(self))
    };
    void (*st_objc_msgSendSuper)(void *, SEL, id) = (void *)objc_msgSendSuper;
    st_objc_msgSendSuper(&superclass, _cmd, newValue);
    //    objc_msgSendSuper(&superclass, _cmd, newValue); // 直接调用编译器会报错: too many arguements
    
    // 查找观察者并调用传进来的 selector
    NSMutableArray *observers = objc_getAssociatedObject(self, (__bridge const void *)(kSTKVOAssociatedObservers));
    for (STObservationInfo *info in observers) {
        if ([info.key isEqualToString:getterName]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            [info.observer performSelector:info.selector withObject:nil];
#pragma clang diagnostic pop
        }
    }
}

@end
