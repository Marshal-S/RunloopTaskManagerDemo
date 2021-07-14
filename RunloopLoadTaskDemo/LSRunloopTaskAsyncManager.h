//
//  LSRunloopTaskExManager.h
//  RunloopLoadTaskDemo
//
//  Created by Marshal on 2021/7/13.
//  runloop加载任务管理类，runloop即将休眠时调用任务，一次执行一个，且任务执行完毕可以选择是否删除

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface LSRunloopTaskAsyncManager : NSObject

//默认全局单例(推荐使用这个)
+ (instancetype)sharedInstance;

//弱引用单例，当没有被引用时会释放,返回的对象类似临时变量，会随着这轮的自动释放池释放，及时保存
+ (instancetype)weakSingleInstance;

//key可以是任何类型，以指针的方式保存到NSMapTable中，可最大幅度避免任务数量，任务被放到子队列按顺序同步执行，默认执行完毕后移除任务
- (void)setAsyncTaskBlock:(void (^)(void))taskBlock forKey:(id)key;

//key可以是任何类型，以指针的方式保存到NSMapTable中，可最大幅度避免任务数量，任务被放到子队列按顺序同步执行, executeLeave是否执行完毕后移除任务
- (void)setAsyncTaskBlock:(void (^)(void))taskBlock forKey:(id)key executeLeave:(BOOL)executeLeave;

@end

NS_ASSUME_NONNULL_END
