//
//  ViewController.m
//  RunloopLoadTaskDemo
//
//  Created by Marshal on 2021/7/12.
//

#import "ViewController.h"
#import "LSRunloopTaskManager.h"
#import "LSRunloopTaskAsyncManager.h"

@interface ViewController ()<UITableViewDataSource, UITableViewDelegate>

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initTableView];
}

- (void)initTableView {
    UITableView *tableView = [[UITableView alloc] initWithFrame:self.view.frame style:UITableViewStylePlain];
    tableView.dataSource = self;
    tableView.delegate = self;
    [tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"identifier"];
    [self.view addSubview:tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1000;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"identifier" forIndexPath:indexPath];
    cell.textLabel.text = @"测试标题";
    [[LSRunloopTaskManager sharedInstance] setTaskBlock:^{
        cell.textLabel.text = [NSString stringWithFormat:@"测试标题+内容:%ld", indexPath.row];
        [NSThread sleepForTimeInterval:0.1];
    } forKey:cell];
    [[LSRunloopTaskAsyncManager sharedInstance] setAsyncTaskBlock:^{
        [NSThread sleepForTimeInterval:0.1];
        NSLog(@"我是第%ld个cell呀", indexPath.row);
    } forKey:cell];
    return cell;
}


@end 
