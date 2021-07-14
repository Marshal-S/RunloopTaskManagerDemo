//
//  LSRunloopTaskExManager.m
//  RunloopLoadTaskDemo
//
//  Created by Marshal on 2021/7/13.
//

#import "LSRunloopTaskAsyncManager.h"
#import <QuartzCore/QuartzCore.h>

//基本任务节点，目前只支持block，可以避免对象selector和参数的额外引用
@interface LSTaskNode : NSObject
{
@package
    id _key;
    id (^_block)(void);
    BOOL _executeLeave; //是否实行完毕出队
    __unsafe_unretained LSTaskNode *_preNode; //避免造成释放问题，在LSTaskMap释放期间内，其不会被释放，因此可以放心使用
    __unsafe_unretained LSTaskNode *_nextNode;
}

@end

@implementation LSTaskNode


@end

//任务维护的map，由双向链表和哈希表共同组成
@interface LSTaskMap : NSObject
{
    NSMapTable<id, LSTaskNode *> *_mapTable; //主要用来快速查找、去重、避免键值维护
    
    LSTaskNode *_headNode; //头结点 -- 尾进头出
    LSTaskNode *_tailNode; //尾结点
}
//执行任务先进先执行原则
//设置任务Block，更新到队尾，剔除更新重复key的任务
- (void)setTaskBlock:(void (^)(void))taskBlock forKey:(id)key executeLeave:(BOOL)executeLeave;
//队首任务离开
- (void)leaveTask;
//执行一个任务，根据任务类型选择是否离队,结果返回队列是否为空
- (BOOL)executeBlock;
//获取元素
- (LSTaskNode *)taskForKey:(id)key;
//移除某个元素
- (void)removeTaskForKey:(id)key;
//移除所有元素
- (void)removeAllTask;

@end

@implementation LSTaskMap

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mapTable = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory | NSPointerFunctionsObjectPersonality valueOptions:NSPointerFunctionsStrongMemory];

        _headNode = nil;
        _tailNode = nil;
    }
    return self;
}

//设置任务
- (void)setTaskBlock:(void (^)(void))taskBlock forKey:(id)key executeLeave:(BOOL)executeLeave {
    LSTaskNode *node = [_mapTable objectForKey:key];
    if (node) {
        //移动到尾，先到的后执行
        node->_block = [taskBlock copy];
        node->_executeLeave = executeLeave;
        if (node == _tailNode) return;
        if (node == _headNode) {
            _headNode = node->_nextNode;
            _tailNode->_nextNode = node;
            node->_preNode = _tailNode;
            _tailNode = node;
            node->_nextNode = nil;
        }else {
            node->_preNode->_nextNode = node->_nextNode;
            node->_nextNode->_preNode = node->_preNode;
            node->_preNode = _tailNode;
            _tailNode->_nextNode = node;
            _tailNode = node;
            node->_nextNode = nil;
        }
    }else {
        node = [LSTaskNode new];
        node->_key = key;
        node->_block = [taskBlock copy];
        node->_executeLeave = executeLeave;
        node->_preNode = nil;
        node->_nextNode = nil;
        
        //尾进头出, 头结点存在，尾结点就存在
        if (!_headNode) {
            _headNode = node;
            _tailNode = node;
        }else {
            LSTaskNode *lastNode = _tailNode;
            node->_preNode = lastNode;
            lastNode->_nextNode = node;
            _tailNode = node;
        }
        [_mapTable setObject:node forKey:key];
    }
}

//队首元素离开
- (void)leaveTask {
    if (!_headNode) return;
    
    if (_headNode == _tailNode) {
        //只有一个元素
        [_mapTable removeAllObjects];
        _headNode = nil;
        _tailNode = nil;
    }else {
        [_mapTable removeObjectForKey:_headNode->_key];
        _headNode = _headNode->_nextNode;
        _headNode->_preNode = nil;
    }
}

//执行一个任务，根据任务类型选择是否离队,结果返回队列是否为空
- (BOOL)executeBlock {
    if (!_headNode) return true;
    _headNode->_block();

    if (_headNode->_executeLeave) {
        if (_headNode == _tailNode) {
            //只有一个元素
            [_mapTable removeAllObjects];
            _headNode = nil;
            _tailNode = nil;
            
            return true;
        }else {
            [_mapTable removeObjectForKey:_headNode->_key];
            _headNode = _headNode->_nextNode;
            _headNode->_preNode = nil;
            
            return false;
        }
    }else {
        return _headNode == _tailNode;
    }
}

- (LSTaskNode *)taskForKey:(id)key {
    return [_mapTable objectForKey:key];
}

- (void)removeTaskForKey:(id)key {
    LSTaskNode *node = [_mapTable objectForKey:key];
    if (!node) return;
    
    if (_headNode == _tailNode) {
        [_mapTable removeAllObjects];
        _headNode = nil;
        _tailNode = nil;
        return;
    }
    if (node == _headNode) {
        _headNode = node->_nextNode;
        _headNode->_preNode = nil;
    }else if (node == _tailNode) {
        _tailNode = node->_preNode;
        _tailNode->_nextNode = nil;
    }else {
        node->_nextNode->_preNode = node->_preNode;
        node->_preNode->_nextNode = node->_nextNode;
    }
    [_mapTable removeObjectForKey:key];
}

- (void)removeAllTask {
    [_mapTable removeAllObjects];
    _headNode = nil;
    _tailNode = nil;
}

@end

@interface LSRunloopTaskAsyncManager ()
{
    LSTaskMap *_taskMap;
    CFRunLoopObserverRef _observer;
    
    dispatch_queue_t _queue; //串行队列，这里面使用的
    BOOL _canExecute;
//    dispatch_semaphore_t _semaphore;
}

@end

@implementation LSRunloopTaskAsyncManager

- (instancetype)init
{
    self = [super init];
    if (self) {
        _taskMap = [[LSTaskMap alloc] init];
        _queue = dispatch_queue_create("LSRunloopTaskExManager", DISPATCH_QUEUE_SERIAL);
//        _semaphore = dispatch_semaphore_create(0);
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
    static __weak LSRunloopTaskAsyncManager *weakInstance = nil;
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
- (void)setAsyncTaskBlock:(void (^)(void))taskBlock forKey:(id)key {
    [_taskMap setTaskBlock:taskBlock forKey:key executeLeave:YES];
    if (!_observer) [self registerObserver];
}

- (void)setAsyncTaskBlock:(void (^)(void))taskBlock forKey:(id)key executeLeave:(BOOL)executeLeave {
    [_taskMap setTaskBlock:taskBlock forKey:key executeLeave:executeLeave];
    if (!_observer) [self registerObserver];
}

////默认可以子线程默认执行的任务
- (void)executeTasks {
    dispatch_async(_queue, ^{
        self->_canExecute = true;
        while (self->_canExecute) {
            if ([self->_taskMap executeBlock]) {
                self->_canExecute = false;
                [self removeObserver];
            }
        }
    });
}

//在主线程执行任务时的操作逻辑
//- (void)executeTasks {
//    if (_canExecute) return;
//
//    dispatch_async(_queue, ^{
//        self->_canExecute = true;
//        CFTimeInterval lastInterval = CACurrentMediaTime();
//        while (self->_canExecute) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//                if ([self->_taskMap executeBlock]) {
//                    self->_canExecute = false;
//                    [self removeObserver];
//                }
//                dispatch_semaphore_signal(self->_semaphore);
//            });
//            dispatch_semaphore_wait(self->_semaphore, DISPATCH_TIME_FOREVER);
//            CFTimeInterval interval = CACurrentMediaTime();
//            if (interval - lastInterval > 0.1) {
//                [NSThread sleepForTimeInterval:0.1];
//                lastInterval = interval;
//            }
//        }
//    });
//}

void __runloopTaskExCallback(CFRunLoopObserverRef observer, CFRunLoopActivity activity, void *info) {
    if (activity == kCFRunLoopBeforeWaiting) {
        [[LSRunloopTaskAsyncManager sharedInstance] executeTasks];
    }else {
        [LSRunloopTaskAsyncManager sharedInstance]->_canExecute = false;
    }
}

//每次即将进入休眠调用回调方法
- (void)registerObserver {
    CFRunLoopObserverContext context = {0, (__bridge void *)self, NULL, NULL};
    _observer = CFRunLoopObserverCreate(kCFAllocatorDefault, kCFRunLoopBeforeWaiting | kCFRunLoopBeforeSources, YES, 0, &__runloopTaskExCallback, &context);
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
