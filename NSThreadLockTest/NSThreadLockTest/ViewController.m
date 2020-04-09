//
//  ViewController.m
//  NSThreadLockTest
//
//  Created by Ivan_deng on 2017/12/5.
//  Copyright © 2017年 Ivan_deng. All rights reserved.
//

#import "ViewController.h"

typedef int(^SUMBlock)(int num1,int num2);

@interface ViewController ()

{
    SUMBlock myBLock;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
  [self dispatch_barrierTest];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (void)getMyBlock:(SUMBlock)block {
    myBLock = [block copy];
}

// 验证syncDispatch是否是停止当前GCD所在线程，等待GCDBlock执行完毕之后才继续
// 测试内容：主线程同步使用GCD，调用全局队列执行任务，看全局队列任务执行中主线程是否停止

- (void)syncTheoryTest {
  dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
  dispatch_queue_t serialQueue = dispatch_queue_create("com.ibabylabs.www.serialQueue", DISPATCH_QUEUE_SERIAL);
  // 主线程中指派全局队列执行任务
  dispatch_async(globalQueue, ^{
    NSLog(@"Global thread ready to dispatch");
    dispatch_sync(serialQueue, ^{
      for (int i = 0; i < 40; i++) {
        NSLog(@"Serial queue block running %d", i);
      }
    });
    NSLog(@"Global thread continue to run.");
  });
}

// 验证结果:成功，使用syncDispatch会停止当前线程等待block执行完毕

// SyncBarrier ：栅栏在同步线程展开，因此会阻塞主线程的其他任务，在栅栏展开之后主线程的任务才会继续执行
- (void)dispatch_barrierTest {
    dispatch_queue_t global = dispatch_queue_create("TELLME", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(global, ^{
        NSLog(@"Test1");
    });
    dispatch_async(global, ^{
        NSLog(@"Test2");
    });
    
    dispatch_barrier_sync(global, ^{
        NSLog(@"Here comes the barrier ! -------------------");
    });
    
    dispatch_async(global, ^{
        NSLog(@"Test3");
    });
    NSLog(@"Main queue operations A.");
    NSLog(@"Main queue operations B.");
    NSLog(@"Main queue operations C.");
}

// AsyncBarrier 栅栏在异步线程中展开，主线程任务不受影响，栅栏只阻隔其他的异步线程
- (void)dispatch_async_barrierTest {
    dispatch_queue_t global = dispatch_queue_create("TELLME", DISPATCH_QUEUE_CONCURRENT);
    
    dispatch_async(global, ^{
        NSLog(@"Test1");
    });
    dispatch_async(global, ^{
        NSLog(@"Test2");
    });
    
    dispatch_barrier_async(global, ^{
        NSLog(@"Here comes the barrier ! -------------------");
    });
    
    dispatch_async(global, ^{
        NSLog(@"Test3");
    });
    NSLog(@"Main queue operations A.");
    NSLog(@"Main queue operations B.");
    NSLog(@"Main queue operations C.");
}

- (void)synchronizeLockTest {
    NSObject *randomLock = [[NSObject alloc]init];
    
    dispatch_queue_t global = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    dispatch_async(global, ^{
        @synchronized(randomLock) {
            [self threadCRunning];
        }
    });
    dispatch_async(global, ^{
        @synchronized(randomLock) {
            [self threadARunning];
        }
    });
}

- (void)nslockTest {
    
    NSLock *threadLock = [[NSLock alloc]init];
    
    NSThread *threadA = [[NSThread alloc]initWithBlock:^{
        [threadLock lock];
        [self threadARunning];
        [threadLock unlock];
    }];
    NSThread *threadB = [[NSThread alloc]initWithBlock:^{
        [threadLock lock];
        [self threadBRunning];
        [threadLock unlock];
    }];
    NSThread *threadC = [[NSThread alloc]initWithBlock:^{
        [threadLock lock];
        [self threadCRunning];
        [threadLock unlock];
    }];
    
    [threadA start];
    [threadB start];
    [threadC start];
    
}

- (void)lockTestWithDispatch {
    
    NSLock *newLock = [[NSLock alloc]init];
    
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(globalQueue, ^{
        [newLock lock];
        [self threadARunning];
        [newLock unlock];
    });
    
    dispatch_async(globalQueue, ^{
        [newLock lock];
        [self threadCRunning];
        [newLock unlock];
    });
}

- (void)threadRunningTestWithDispatch {
    dispatch_queue_t myQueue = [ViewController getQueue];
    dispatch_async(myQueue, ^{
        [self threadARunning];
    });
    dispatch_async(myQueue, ^{
        [self threadBRunning];
    });
    dispatch_async(myQueue, ^{
        [self threadCRunning];
    });
}

+ (dispatch_queue_t)getQueue {
    static dispatch_once_t onceToken;
    static dispatch_queue_t concurrentQueue = nil;
    dispatch_once(&onceToken, ^{
        concurrentQueue = dispatch_queue_create("myQueue", DISPATCH_QUEUE_SERIAL);
    });
    return concurrentQueue;
}

- (void)semaphoreTest {
    //创建信号阻塞管道，当参数为1时表示为互斥锁
    dispatch_semaphore_t signalPipe = dispatch_semaphore_create(1);
    //创建等待时间，第一个参数表示即时到无穷秒，第二个参数表示微秒。
    dispatch_time_t overTime = dispatch_time(DISPATCH_TIME_FOREVER, 3 * NSEC_PER_SEC);
    dispatch_queue_t globalQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(globalQueue, ^{
        //将信号管道阻塞，表示这个异步线程并发队列中的任务会占用管道，信号量为0了，其他队列中的任务无法执行。
        dispatch_semaphore_wait(signalPipe, overTime);
        [self threadARunning];
        //队列中的这个任务执行完毕之后，线程管道畅通，其他任务可以执行了。
        dispatch_semaphore_signal(signalPipe);
    });
    
    //测试semaphore能不能跨队列影响其他任务
    dispatch_queue_t mainQueue = dispatch_get_main_queue();
    dispatch_async(mainQueue, ^{
        dispatch_semaphore_wait(signalPipe, DISPATCH_TIME_FOREVER);
        [self threadBRunning];
        dispatch_semaphore_signal(signalPipe);
        //由运行结果可得，哪怕不是同一队列中的异步线程任务，仍然可以通过此方法阻塞所有异步线程。
    });
}

- (void)threadARunning {
    for(int i = 0; i < 26; i++) {
        NSLog(@"Accending:%d",i);
    }
    NSLog(@"Running Thread is : %@",[NSThread currentThread]);
}

- (void)threadBRunning {
    for(int i = 100; i > 84; i--) {
        NSLog(@"Deccending:%d",i);
    }
    NSLog(@"Running Thread is : %@",[NSThread currentThread]);
}

- (void)threadCRunning {
    NSArray *sample = @[@"a",@"b",@"c",@"d",@"e",@"f",@"g"];
    for(NSString *single in sample) {
        NSLog(@"Letters: %@",single);
    }
    NSLog(@"Running Thread is : %@",[NSThread currentThread]);
}

@end
