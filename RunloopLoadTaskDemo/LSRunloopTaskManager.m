//
//  RunloopTaskManager.m
//  RunloopLoadTaskDemo
//
//  Created by Marshal on 2021/7/13.
//

#import "LSRunloopTaskManager.h"

@interface LSRunloopTaskManager ()
{
    NSMapTable *_mapTable;
    CFRunLoopObserverRef _observer;
}

@end

@implementation LSRunloopTaskManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPointerPersonality valueOptions:NSPointerFunctionsStrongMemory];
    }
    return self;
}

+ (instancetype)sharedInstance {
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

+ (instancetype)weakSingleInstance {
    static __weak LSRunloopTaskManager *weakInstance = nil;
    __strong id strongInstance = weakInstance;
    @synchronized (self) {
        if (!weakInstance) {
            strongInstance = [[self alloc] init];
            weakInstance = strongInstance;
        }
    }
    return strongInstance;
}

//当开始监听是创建register，避免实际没有任务时，runloop总被唤醒，虽然系统优化runloop唤醒逻辑，还是避免过多的性能消耗
- (void)setTaskBlock:(void (^)(void))taskBlock forKey:(id)key {
    NSAssert([NSThread isMainThread], @"任务必须在主线程中设置");
    
    [_mapTable setObject:[taskBlock copy] forKey:key];
    if (!_observer) [self registerObserver];
}

void __runloopTaskCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    NSMapTable *mapTable = [LSRunloopTaskManager sharedInstance]->_mapTable;
    for (id key in mapTable) {
        void (^block)(void) = [mapTable objectForKey:key];
        block();
    }
    [mapTable removeAllObjects];
    //执行完毕所有任务之后，关闭observer，避免runloop总是被唤醒，迟迟无法进入休眠状态
    [[LSRunloopTaskManager sharedInstance] removeObserver];
}

//每次即将进入休眠调用回调方法
- (void)registerObserver {
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    _observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, YES, 0, &__runloopTaskCallback, &context);
    CFRunLoopAddObserver(CFRunLoopGetMain(), _observer, kCFRunLoopDefaultMode);
}

- (void)removeObserver {
    if (_observer == NULL) return;
    
    CFRunLoopRemoveObserver(CFRunLoopGetMain(), _observer, kCFRunLoopDefaultMode);
    CFRelease(_observer);
    _observer = NULL;
}

- (void)dealloc {
    [self removeObserver];
}

@end
