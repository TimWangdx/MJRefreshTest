//  代码地址: https://github.com/CoderMJLee/MJRefresh
//  代码地址: http://code4app.com/ios/%E5%BF%AB%E9%80%9F%E9%9B%86%E6%88%90%E4%B8%8B%E6%8B%89%E4%B8%8A%E6%8B%89%E5%88%B7%E6%96%B0/52326ce26803fabc46000000
//  MJRefreshComponent.m
//  MJRefreshExample
//
//  Created by MJ Lee on 15/3/4.
//  Copyright (c) 2015年 小码哥. All rights reserved.
//

#import "MJRefreshComponent.h"
#import "MJRefreshConst.h"

@interface MJRefreshComponent()
@property (strong, nonatomic) UIPanGestureRecognizer *pan;
@end

@implementation MJRefreshComponent
#pragma mark - 初始化
- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        // 准备工作
        [self prepare];
        
        // 默认是普通状态
        self.state = MJRefreshStateIdle;
    }
    return self;
}

- (void)prepare
{
    // 基本属性
    
    // 自动调整自己的宽度，保证与superView左边和右边的距离不变。
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    
    // 背景色为透明色
    self.backgroundColor = [UIColor clearColor];
}

// 布局子控件，这个类没有subview
- (void)layoutSubviews
{
    [self placeSubviews];
    
    [super layoutSubviews];
}

// 这个基类没有sub view
- (void)placeSubviews{}


- (void)willMoveToSuperview:(UIView *)newSuperview
{
    [super willMoveToSuperview:newSuperview];
    
    // 如果不是UIScrollView，不做任何事情
    if (newSuperview && ![newSuperview isKindOfClass:[UIScrollView class]]) return;
    
    // 旧的父控件移除监听
    [self removeObservers];
    
    if (newSuperview) { // 新的父控件
        // 设置宽度
        self.mj_w = newSuperview.mj_w;
        // 设置位置
        self.mj_x = 0;
        
        // 记录UIScrollView
        _scrollView = (UIScrollView *)newSuperview;
        // 设置永远支持垂直弹簧效果
        _scrollView.alwaysBounceVertical = YES;
        // 记录UIScrollView最开始的contentInset
        _scrollViewOriginalInset = _scrollView.contentInset;
        
        // 添加监听
        [self addObservers];
    }
}

- (void)drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    if (self.state == MJRefreshStateWillRefresh) {
        // 预防view还没显示出来就调用了beginRefreshing
        self.state = MJRefreshStateRefreshing;
    }
}

#pragma mark - KVO监听
- (void)addObservers
{
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld;
    
    // kvo,对scrollview的contentOffset,contentSize的监听
    [self.scrollView addObserver:self forKeyPath:MJRefreshKeyPathContentOffset options:options context:nil];
    [self.scrollView addObserver:self forKeyPath:MJRefreshKeyPathContentSize options:options context:nil];
    
    // 监听pan手势的状态
    self.pan = self.scrollView.panGestureRecognizer;
    [self.pan addObserver:self forKeyPath:MJRefreshKeyPathPanState options:options context:nil];
}

- (void)removeObservers
{
    // 移除对scrollview contentOffset，contentSize的监听
    [self.superview removeObserver:self forKeyPath:MJRefreshKeyPathContentOffset];
    [self.superview removeObserver:self forKeyPath:MJRefreshKeyPathContentSize];
    
    // 移除对手势的state的监听
    [self.pan removeObserver:self forKeyPath:MJRefreshKeyPathPanState];
    self.pan = nil;
}

// kvc的监听方法
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    // 遇到这些情况就直接返回
    if (!self.userInteractionEnabled) return;
    
    // 这个就算看不见也需要处理
    if ([keyPath isEqualToString:MJRefreshKeyPathContentSize]) {
        [self scrollViewContentSizeDidChange:change];
    }
    
    // 看不见
    if (self.hidden) return;
    
    if ([keyPath isEqualToString:MJRefreshKeyPathContentOffset]) {
        [self scrollViewContentOffsetDidChange:change];
    } else if ([keyPath isEqualToString:MJRefreshKeyPathPanState]) {
        [self scrollViewPanStateDidChange:change];
    }
}

// contentOffset 发生改变
- (void)scrollViewContentOffsetDidChange:(NSDictionary *)change{}

// contentSize 发生改变
- (void)scrollViewContentSizeDidChange:(NSDictionary *)change{}

// pan手势状态发生改变
- (void)scrollViewPanStateDidChange:(NSDictionary *)change{}

#pragma mark - 公共方法
#pragma mark 设置回调对象和回调方法
// 设置刷新的目标对象和方法
- (void)setRefreshingTarget:(id)target refreshingAction:(SEL)action
{
    self.refreshingTarget = target;
    self.refreshingAction = action;
}

// 设置状态
- (void)setState:(MJRefreshState)state
{
    _state = state;
    
    // 加入主队列的目的是等setState:方法调用完毕、设置完文字后再去布局子控件
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
    });
}

#pragma mark 进入刷新状态
- (void)beginRefreshing
{
    [UIView animateWithDuration:MJRefreshFastAnimationDuration animations:^{
        self.alpha = 1.0;
    }];
    self.pullingPercent = 1.0;
    // 只要正在刷新，就完全显示
    if (self.window) {
        self.state = MJRefreshStateRefreshing;
    } else {
        // 预防正在刷新中时，调用本方法使得header inset回置失败
        if (self.state != MJRefreshStateRefreshing) {
            self.state = MJRefreshStateWillRefresh;
            // 刷新(预防从另一个控制器回到这个控制器的情况，回来要重新刷新一下)
            [self setNeedsDisplay];
        }
    }
}

- (void)beginRefreshingWithCompletionBlock:(void (^)())completionBlock
{
    // 开始刷新
    self.beginRefreshingCompletionBlock = completionBlock;
    
    [self beginRefreshing];
}

#pragma mark 结束刷新状态
- (void)endRefreshing
{
    // 结束刷新，设置状态
    self.state = MJRefreshStateIdle;
}

- (void)endRefreshingWithCompletionBlock:(void (^)())completionBlock
{
    // 结束刷新状态
    self.endRefreshingCompletionBlock = completionBlock;
    
    [self endRefreshing];
}

#pragma mark 是否正在刷新
- (BOOL)isRefreshing
{
    // 是否正在刷新
    return self.state == MJRefreshStateRefreshing || self.state == MJRefreshStateWillRefresh;
}

#pragma mark 自动切换透明度
- (void)setAutoChangeAlpha:(BOOL)autoChangeAlpha
{
    self.automaticallyChangeAlpha = autoChangeAlpha;
}

- (BOOL)isAutoChangeAlpha
{
    return self.isAutomaticallyChangeAlpha;
}

- (void)setAutomaticallyChangeAlpha:(BOOL)automaticallyChangeAlpha
{
    // 设置开启自动变化，就去设置下透明度
    _automaticallyChangeAlpha = automaticallyChangeAlpha;
    
    if (self.isRefreshing) return;
    
    if (automaticallyChangeAlpha) {
        self.alpha = self.pullingPercent;
    } else {
        self.alpha = 1.0;
    }
}

#pragma mark 根据拖拽进度设置透明度
- (void)setPullingPercent:(CGFloat)pullingPercent
{
    // 设置透明度
    _pullingPercent = pullingPercent;
    
    if (self.isRefreshing) return;
    
    if (self.isAutomaticallyChangeAlpha) {
        self.alpha = pullingPercent;
    }
}

#pragma mark - 内部方法
- (void)executeRefreshingCallback
{
    // 执行刷新
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.refreshingBlock) {
            self.refreshingBlock();
        }
        if ([self.refreshingTarget respondsToSelector:self.refreshingAction]) {
            MJRefreshMsgSend(MJRefreshMsgTarget(self.refreshingTarget), self.refreshingAction, self);
        }
        if (self.beginRefreshingCompletionBlock) {
            self.beginRefreshingCompletionBlock();
        }
    });
}
@end

@implementation UILabel(MJRefresh)

// 返回label
+ (instancetype)mj_label
{
    UILabel *label = [[self alloc] init];
    label.font = MJRefreshLabelFont;
    label.textColor = MJRefreshLabelTextColor;
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    label.textAlignment = NSTextAlignmentCenter;
    label.backgroundColor = [UIColor clearColor];
    return label;
}

// 获取字体的宽度
- (CGFloat)mj_textWith {
    CGFloat stringWidth = 0;
    CGSize size = CGSizeMake(MAXFLOAT, MAXFLOAT);
    if (self.text.length > 0) {
#if defined(__IPHONE_OS_VERSION_MAX_ALLOWED) && __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        stringWidth =[self.text
                      boundingRectWithSize:size
                      options:NSStringDrawingUsesLineFragmentOrigin
                      attributes:@{NSFontAttributeName:self.font}
                      context:nil].size.width;
#else
        
        stringWidth = [self.text sizeWithFont:self.font
                             constrainedToSize:size
                                 lineBreakMode:NSLineBreakByCharWrapping].width;
#endif
    }
    return stringWidth;
}

@end