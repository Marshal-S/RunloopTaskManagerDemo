//
//  RunloopTaskManager.h
//  RunloopLoadTaskDemo
//
//  Created by Marshal on 2021/7/13.
//  runloop加载任务管理类，runloop即将休眠时调用任务,即将休眠时执行所有任务

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSRunloopTaskManager : NSObject

//默认全局单例(推荐使用这个)
+ (instancetype)sharedInstance;

//弱引用单例，当没有被引用时会释放,返回的对象类似临时变量，会随着这轮的自动释放池释放，及时保存
+ (instancetype)weakSingleInstance;

//key可以是任何类型，以指针的方式保存到NSMapTable中，可最大幅度避免任务数量
- (void)setTaskBlock:(void (^)(void))taskBlock forKey:(id)key;

@end

NS_ASSUME_NONNULL_END
