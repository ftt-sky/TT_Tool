//
//  TT_PageScrollV.m
//  XXX
//
//  Created by 樊腾 on 2019/9/22.
//  Copyright © 2019 绑耀. All rights reserved.
//

#import "TT_PageScrollV.h"
#import "TT_CommentMaco.h"
#import "TT_CommentTool.h"
#define kTabDefautHeight 38.0
#define kTabDefautFontSize 15.0
#define kMaxNumberOfPageItems 8

#define kIndicatorHeight 2.0
#define kIndicatorWidth 20
#define kMinScale 0.8

#define HEIGHT(view) view.bounds.size.height
#define WIDTH(view) view.bounds.size.width
#define ORIGIN_X(view) view.frame.origin.x
#define ORIGIN_Y(view) view.frame.origin.y

@interface TT_PageScrollV () <UIScrollViewDelegate>
//bg
@property (nonatomic, strong) UIView *bgView; //由于遇到nav->vc，vc的第一个子试图是UIScrollView会自动产生64像素偏移，所以加上一个虚拟背景（没有尺寸）
//data
@property (nonatomic, assign) NSInteger lastSelectedTabIndex; //记录上一次的索引
@property (nonatomic, assign) NSInteger numberOfTabItems;
@property (nonatomic, assign) CGFloat tabItemWidth;

@property (nonatomic, strong) NSArray *childControllers;
@property (nonatomic, strong) NSArray *childTitles;

//animation
@property (nonatomic, assign) BOOL isNeedRefreshLayout; //滑动过程中不允许layoutSubviews
@property (nonatomic, assign) BOOL isChangeByClick; //是否是通过点击改变的。因为点击可以长距离点击，部分效果不作处理会出现途中经过的按钮也会依次有效果（仿网易客户端有此效果，个人觉得并不好，头条的客户端更合理）
@property (nonatomic, assign) NSInteger leftItemIndex; //记录滑动时左边的itemIndex
@property (nonatomic, assign) NSInteger rightItemIndex; //记录滑动时右边的itemIndex

/*XXPageTabTitleStyleScale*/
@property (nonatomic, assign) CGFloat selectedColorR;
@property (nonatomic, assign) CGFloat selectedColorG;
@property (nonatomic, assign) CGFloat selectedColorB;
@property (nonatomic, assign) CGFloat unSelectedColorR;
@property (nonatomic, assign) CGFloat unSelectedColorG;
@property (nonatomic, assign) CGFloat unSelectedColorB;
@property (nonatomic, strong) UILabel*  bottomLive;
@property (nonatomic, strong) UIView *TopView;



@end

@implementation TT_PageScrollV

#pragma mark - Life cycle
- (instancetype)initWithChildControllers:(NSArray<UIViewController *> *)childControllers
                             childTitles:(NSArray<NSString *> *)childTitles {
    self = [super init];
    if(self) {
        [self initBaseSettings];
        _childControllers = childControllers;
        _childTitles = childTitles;
        _numberOfTabItems = _childControllers.count>_childTitles.count?_childTitles.count:_childControllers.count;
        _is_bodyScroll = YES;
        [self initTabView];
        [self initMainView];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame Controllers:(NSArray<UIViewController *> *)childControllers childTitles:(NSArray<NSString *> *)childTitles {
    self = [super initWithFrame:frame];
    if (self) {
        [self initBaseSettings];
        _childControllers = childControllers;
        _childTitles = childTitles;
        _numberOfTabItems = _childControllers.count>_childTitles.count?_childTitles.count:_childControllers.count;
        _is_bodyScroll = YES;
        [self initTabView];
        [self initMainView];
    }
    return self;
    
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _is_bodyScroll = YES;
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _is_bodyScroll = YES;
    }
    return self;
}
- (void)configControllers:(NSArray<UIViewController *> *)childControllers childTitles:(NSArray<NSString *> *)childTitles {
    [self initBaseSettings];
    _childControllers = childControllers;
    _childTitles = childTitles;
    _numberOfTabItems = _childControllers.count>_childTitles.count?_childTitles.count:_childControllers.count;
    [self initTabView];
    [self initMainView];
}

- (void)layoutSubviews {
    if(_isNeedRefreshLayout) {
        //tab layout
        if(_tabSize.height <= 0) {
            _tabSize.height = kTabDefautHeight;
        }
        if(_tabSize.width <= 0) {
            _tabSize.width = WIDTH(self);
        }
        _tabItemWidth = _tabSize.width/(_numberOfTabItems<_maxNumberOfPageItems?_numberOfTabItems:_maxNumberOfPageItems);
        
        self.tabView.frame = CGRectMake(0, 0, _tabSize.width, _tabSize.height);
        self.tabView.contentSize = CGSizeMake(_tabItemWidth*_numberOfTabItems, 0);
        
        for(NSInteger i = 0; i < _tabItems.count; i++) {
            TT_PageTabItemLable *tabItem = (TT_PageTabItemLable *)_tabItems[i];
            tabItem.frame = CGRectMake(_tabItemWidth*i, 0, _tabItemWidth, _tabSize.height);
        }
        
        //body layout
        if (self.isShowLine ==1) {
            self.tabView.frame = CGRectMake(self.tabItemX, 0, _tabSize.width, _tabSize.height);
            self.bottomLive.frame = CGRectMake(self.tabItemX, _tabSize.height, WIDTH(self) - (self.tabItemX * 2 ), 1);
            self.bodyView.frame = CGRectMake(0, CGRectGetMaxY(self.bottomLive.frame)+1, WIDTH(self), HEIGHT(self)-CGRectGetMaxY(self.bottomLive.frame));
        }else {
            self.bodyView.frame = CGRectMake(0, _tabSize.height, WIDTH(self), HEIGHT(self)-_tabSize.height);
        }
        self.bodyView.contentSize = CGSizeMake(WIDTH(self)*_numberOfTabItems, 0);
        self.bodyView.contentOffset = CGPointMake(self.frame.size.width*_selectedTabIndex, 0);
        [self reviseTabContentOffsetBySelectedIndex:NO];
        [self layoutIndicatorViewWithStyle];
        for(NSInteger i = 0; i < _numberOfTabItems; i++) {
            UIViewController *childController = _childControllers[i];
            childController.view.frame = CGRectMake(WIDTH(self)*i, 0, WIDTH(self), HEIGHT(self)-_tabSize.height);
        }
    }
}
#pragma mark - Layout
- (void)initBaseSettings {
    _selectedTabIndex = 0;
    _lastSelectedTabIndex = 0;
    _tabSize = CGSizeZero;
    _tabItemFont = [UIFont systemFontOfSize:kTabDefautFontSize];
    _indicatorHeight = kIndicatorHeight;
    _indicatorWidth = kIndicatorWidth;
    _maxNumberOfPageItems = kMaxNumberOfPageItems;
    _tabItems = [NSMutableArray array];
    _tabBackgroundColor = [TT_DarkmodeTool TT_NormalWhite];
    _bodyBackgroundColor = [TT_DarkmodeTool TT_NormalWhite];
    _unSelectedColor = [UIColor blackColor];
    _selectedColor = [UIColor redColor];
    _isNeedRefreshLayout = YES;
    _isChangeByClick = NO;
    _bodyBounces = YES;
    _titleStyle = TT_PageTabTitleStyleDefault;
    _indicatorStyle = TT_PageTabIndicatorStyleDefault;
    _minScale = kMinScale;
    _selectedColorR = 1;
    _selectedColorG = 0;
    _selectedColorB = 0;
    _unSelectedColorR = 0;
    _unSelectedColorG = 0;
    _unSelectedColorB = 0;
    _title_BGColor = [UIColor redColor];
}

- (void)initTabView {
    [self.tabView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    [self addSubview:self.bgView];
    [self addSubview:self.tabView];
    for(NSInteger i = 0; i < _numberOfTabItems; i++) {
        TT_PageTabItemLable *tabItem = [[TT_PageTabItemLable alloc] init];
        tabItem.font = _tabItemFont;
        tabItem.text = _childTitles[i];
        tabItem.textColor = i==_selectedTabIndex?_selectedColor:_unSelectedColor;
        tabItem.textAlignment = NSTextAlignmentCenter;
        tabItem.userInteractionEnabled = YES;
        tabItem.backgroundColor = [UIColor clearColor];
        
        UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(changeChildControllerOnClick:)];
        [tabItem addGestureRecognizer:tapRecognizer];
        [_tabItems addObject:tabItem];
        [self.tabView addSubview:tabItem];
    }
}

- (void)initMainView {
    [self addSubview:self.bottomLive];
    [self addSubview:self.bodyView];
    
    for(NSInteger i = 0; i < _numberOfTabItems; i++) {
        UIViewController *childController = _childControllers[i];
        [self.bodyView addSubview:childController.view];
    }
}

/**
 根据选择项修正tab的展示区域
 */
- (void)reviseTabContentOffsetBySelectedIndex:(BOOL)isAnimate {
    TT_PageTabItemLable *currentTabItem = _tabItems[_selectedTabIndex];
    CGFloat selectedItemCenterX = currentTabItem.center.x;
    
    CGFloat reviseX;
    if(selectedItemCenterX + _tabSize.width/2.0 >= self.tabView.contentSize.width) {
        reviseX = self.tabView.contentSize.width - _tabSize.width; //不足以到中心，靠右
    } else if(selectedItemCenterX - _tabSize.width/2.0 <= 0) {
        reviseX = 0; //不足以到中心，靠左
    } else {
        reviseX = selectedItemCenterX - _tabSize.width/2.0; //修正至中心
    }
    //如果前后没有偏移量差，setContentOffset实际不起作用；或者没有动画效果
    if(fabs(self.tabView.contentOffset.x - reviseX)<1 || !isAnimate) {
        [self finishReviseTabContentOffset];
    }
    [self.tabView setContentOffset:CGPointMake(reviseX, 0) animated:isAnimate];
}

/**
 tabview修正完成后的操作，无论是点击还是滑动body，此方法都是真正意义上的最后一步
 */
- (void)finishReviseTabContentOffset {
    _tabView.userInteractionEnabled = YES;
    _isNeedRefreshLayout = YES;
    _isChangeByClick = NO;
    if([self.delegate respondsToSelector:@selector(pageTabViewDidEndChange)]) {
        if(_lastSelectedTabIndex != _selectedTabIndex) {
            [self.delegate pageTabViewDidEndChange];
        }
    }
    _lastSelectedTabIndex = _selectedTabIndex;
}

/**
 一般常用改变selected Item方法(无动画效果，直接变色)
 */
- (void)changeSelectedItemToNextItem:(NSInteger)nextIndex {
    
    TT_PageTabItemLable *currentTabItem = _tabItems[_selectedTabIndex];
    TT_PageTabItemLable *nextTabItem = _tabItems[nextIndex];
    
   
    currentTabItem.textColor = _unSelectedColor;
    nextTabItem.textColor = _selectedColor;
    
    
}

#pragma mark -Title layout
/**
 重新设置item的缩放比例
 */
- (void)resetTabItemScale {
    for(NSInteger i = 0; i < _numberOfTabItems; i++) {
        TT_PageTabItemLable *tabItem = _tabItems[i];
        if(i != _selectedTabIndex) {
            tabItem.transform = CGAffineTransformMakeScale(_minScale, _minScale);
        } else {
            tabItem.transform = CGAffineTransformMakeScale(1, 1);
        }
    }
}

#pragma mark -Indicator layout
/**
 根据不同风格添加相应下标
 */
- (void)addIndicatorViewWithStyle {
    switch (_indicatorStyle) {
        case TT_PageTabIndicatorStyleDefault:
        case TT_PageTabIndicatorStyleFollowText:
        case TT_PageTabIndicatorStyleStretch:
            [self addSubview:self.indicatorView];
            break;
        case TT_PageTabTitleStyleBg:
            [self.tabView addSubview:self.title_BG];
            [self.tabView insertSubview:self.title_BG atIndex:0];
            
            break;
        default:
            break;
    }
}

/**
 根据不同风格对下标layout
 */
- (void)layoutIndicatorViewWithStyle {
    switch (_indicatorStyle) {
        case TT_PageTabIndicatorStyleDefault:
        case TT_PageTabIndicatorStyleFollowText:
        case TT_PageTabIndicatorStyleStretch:
            [self layoutIndicatorView];
            break;
        case TT_PageTabIndicatorStyleBg:
            [self layouttitle_Bg];
        default:
            break;
    }
}

/// 设置字体背景布局
- (void)layouttitle_Bg {
    CGFloat title_bgwidth = [self getIndicatorWidthWithTitle:_childTitles[_selectedTabIndex]] + 30;
    TT_PageTabItemLable *selectTabItem = _tabItems[_selectedTabIndex];
    CGFloat fontSize = self.tabItemFont.pointSize + 10;
    self.title_BG.layer.cornerRadius = fontSize / 2;
    self.title_BG.layer.masksToBounds = YES;
    self.title_BG.frame = CGRectMake(selectTabItem.center.x - title_bgwidth / 2 - _tabView.contentOffset.x, (selectTabItem.frame.size.height - fontSize) / 2 , title_bgwidth, fontSize);
    
}

/// 设置下滑线布局
- (void)layoutIndicatorView {
    CGFloat indicatorWidth = [self getIndicatorWidthWithTitle:_childTitles[_selectedTabIndex]];
    TT_PageTabItemLable *selecedTabItem = _tabItems[_selectedTabIndex];
    self.indicatorView.frame = CGRectMake(self.tabItemX + selecedTabItem.center.x-indicatorWidth/2.0-_tabView.contentOffset.x, _tabSize.height-_indicatorHeight, indicatorWidth, _indicatorHeight);
    self.indicatorView.layer.cornerRadius = self.indicatorHeight / 2;
    self.indicatorView.layer.masksToBounds = YES;
}

#pragma mark - Event response
- (void)changeChildControllerOnClick:(UITapGestureRecognizer *)tap {
    NSInteger nextIndex = [_tabItems indexOfObject:tap.view];
    if(nextIndex != _selectedTabIndex) {
        if (self.delegate && [self.delegate respondsToSelector:@selector(titleColorBeginChange:)]) {
               [self.delegate titleColorBeginChange:nextIndex];
           }
        if(_titleStyle == TT_PageTabTitleStyleDefault) {
            [self changeSelectedItemToNextItem:nextIndex];
        }
        _isChangeByClick = YES;
        _tabView.userInteractionEnabled = NO; //防止快速切换
        _leftItemIndex = nextIndex > _selectedTabIndex?_selectedTabIndex:nextIndex;
        _rightItemIndex = nextIndex > _selectedTabIndex?nextIndex:_selectedTabIndex;
        _selectedTabIndex = nextIndex;
        [self.bodyView setContentOffset:CGPointMake(self.frame.size.width*_selectedTabIndex, 0) animated:YES];
    }
}

#pragma mark - UIScrollViewDelegate
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    if(scrollView == self.bodyView) {
        _selectedTabIndex = self.bodyView.contentOffset.x/WIDTH(self.bodyView);
        [self reviseTabContentOffsetBySelectedIndex:YES];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    CGFloat start = scrollView.contentOffset.x;
    if (start > 0 && start < scrollView.contentSize.width - _tabSize.width )  {
            if (self.delegate && [self.delegate respondsToSelector:@selector(pageContentScrollViewWillBeginDragging)]) {
            [self.delegate pageContentScrollViewWillBeginDragging];
        }

    }
}


- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
    if(scrollView == self.bodyView) {
        [self reviseTabContentOffsetBySelectedIndex:YES];
    } else {
        [self finishReviseTabContentOffset];
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if(scrollView == self.tabView) {
        _isNeedRefreshLayout = NO;
        if(self.indicatorView.superview) {
            TT_PageTabItemLable *selecedTabItem = _tabItems[_selectedTabIndex];
            self.indicatorView.frame = CGRectMake(self.tabItemX + selecedTabItem.center.x-WIDTH(self.indicatorView)/2.0-scrollView.contentOffset.x, ORIGIN_Y(self.indicatorView), WIDTH(self.indicatorView), HEIGHT(self.indicatorView));
        }
        
        if (self.title_BG.subviews) {
            TT_PageTabItemLable *selectTabItem = _tabItems[_selectedTabIndex];
            CGFloat fontSize = self.tabItemFont.pointSize + 10;
            self.title_BG.frame =  CGRectMake( selectTabItem.center.x-WIDTH(self.title_BG)/2.0-scrollView.contentOffset.x, (selectTabItem.frame.size.height - fontSize) / 2, WIDTH(self.title_BG), fontSize);
        }
    } else if(scrollView == self.bodyView) {
        //未初始化时不处理
        if(self.bodyView.contentSize.width <= 0) {
            return;
        }
        //滚动过程中不允许layout
        _isNeedRefreshLayout = NO;
        //获取当前左右item index(点击方式已获知左右index，无需根据contentoffset计算)
        if(!_isChangeByClick) {
            if(self.bodyView.contentOffset.x <= 0) { //左边界
                _leftItemIndex = 0;
                _rightItemIndex = 0;
                
            } else if(self.bodyView.contentOffset.x >= self.bodyView.contentSize.width-WIDTH(self.bodyView)) { //右边界
                _leftItemIndex = _numberOfTabItems-1;
                _rightItemIndex = _numberOfTabItems-1;
                
            } else {
                _leftItemIndex = (int)(self.bodyView.contentOffset.x/WIDTH(self.bodyView));
                _rightItemIndex = _leftItemIndex + 1;
            }
        }
        
        //调整title
        switch (_titleStyle) {
            case TT_PageTabTitleStyleDefault:
                [self changeTitleWithDefault];
                break;
            case TT_PageTabTitleStyleGradient:
                [self changeTitleWithGradient];
                break;
            case TT_PageTabTitleStyleBlend:
                [self changeTitleWithBlend];
                break;
            case TT_PageTabTitleStyleBg:
                [self changeTitleWithGradient];
                break;
            default:
                break;
        }
        
        //调整indicator
        switch (_indicatorStyle) {
            case TT_PageTabIndicatorStyleDefault:
            case TT_PageTabIndicatorStyleFollowText:
                [self changeIndicatorFrame];
                break;
            case TT_PageTabIndicatorStyleStretch:
            {
                if(_isChangeByClick) {
                    [self changeIndicatorFrame];
                } else {
                    [self changeIndicatorFrameByStretch];
                }
            }
                break;
            case TT_PageTabIndicatorStyleBg:
                [self changeIndicatorFrame];
                break;
            default:
                break;
        }
    }
}


#pragma mark - Title animation


- (void)changeTitleBg {
    CGFloat leftScale = self.bodyView.contentOffset.x/WIDTH(self.bodyView)-_leftItemIndex;
    if(leftScale == 0) {
        return; //起点和终点不处理，终点时左右index已更新，会绘画错误（你可以注释看看）
    }
    
    TT_PageTabItemLable *leftTabItem = _tabItems[_leftItemIndex];
    TT_PageTabItemLable *rightTabItem = _tabItems[_rightItemIndex];
    
    leftTabItem.textColor = _selectedColor;
    rightTabItem.textColor = _unSelectedColor;
    leftTabItem.fillColor = _unSelectedColor;
    rightTabItem.fillColor = _selectedColor;
    leftTabItem.process = leftScale;
    rightTabItem.process = leftScale;
}
- (void)changeTitleWithDefault {
    CGFloat relativeLocation = self.bodyView.contentOffset.x/WIDTH(self.bodyView)-_leftItemIndex;
    if(!_isChangeByClick) {
        if(relativeLocation > 0.5) {
            [self changeSelectedItemToNextItem:_rightItemIndex];
            _selectedTabIndex = _rightItemIndex;
        } else {
            [self changeSelectedItemToNextItem:_leftItemIndex];
            _selectedTabIndex = _leftItemIndex;
        }
    }
}

- (void)changeTitleWithGradient {
    if(_leftItemIndex != _rightItemIndex) {
        CGFloat rightScale = (self.bodyView.contentOffset.x/WIDTH(self.bodyView)-_leftItemIndex)/(_rightItemIndex-_leftItemIndex);
        CGFloat leftScale = 1-rightScale;
        
        //颜色渐变
        CGFloat difR = _selectedColorR-_unSelectedColorR;
        CGFloat difG = _selectedColorG-_unSelectedColorG;
        CGFloat difB = _selectedColorB-_unSelectedColorB;
        
        UIColor *leftItemColor = [UIColor colorWithRed:_unSelectedColorR+leftScale*difR green:_unSelectedColorG+leftScale*difG blue:_unSelectedColorB+leftScale*difB alpha:1];
        UIColor *rightItemColor = [UIColor colorWithRed:_unSelectedColorR+rightScale*difR green:_unSelectedColorG+rightScale*difG blue:_unSelectedColorB+rightScale*difB alpha:1];
        
        TT_PageTabItemLable *leftTabItem = _tabItems[_leftItemIndex];
        TT_PageTabItemLable *rightTabItem = _tabItems[_rightItemIndex];
        leftTabItem.textColor = leftItemColor;
        rightTabItem.textColor = rightItemColor;
        
        //字体渐变
        leftTabItem.transform = CGAffineTransformMakeScale(_minScale+(1-_minScale)*leftScale, _minScale+(1-_minScale)*leftScale);
        rightTabItem.transform = CGAffineTransformMakeScale(_minScale+(1-_minScale)*rightScale, _minScale+(1-_minScale)*rightScale);
    }
}

- (void)changeTitleWithBlend {
    CGFloat leftScale = self.bodyView.contentOffset.x/WIDTH(self.bodyView)-_leftItemIndex;
    if(leftScale == 0) {
        return; //起点和终点不处理，终点时左右index已更新，会绘画错误（你可以注释看看）
    }
    
    TT_PageTabItemLable *leftTabItem = _tabItems[_leftItemIndex];
    TT_PageTabItemLable *rightTabItem = _tabItems[_rightItemIndex];
    
    leftTabItem.textColor = _selectedColor;
    rightTabItem.textColor = _unSelectedColor;
    leftTabItem.fillColor = _unSelectedColor;
    rightTabItem.fillColor = _selectedColor;
    leftTabItem.process = leftScale;
    rightTabItem.process = leftScale;
}

#pragma mark - Indicator animation
- (void)changeIndicatorFrame {
    //计算indicator此时的centerx
    CGFloat nowIndicatorCenterX = _tabItemWidth*(0.5+self.bodyView.contentOffset.x/WIDTH(self.bodyView));
    //计算此时body的偏移量在一页中的占比
    CGFloat relativeLocation = (self.bodyView.contentOffset.x/WIDTH(self.bodyView)-_leftItemIndex)/(_rightItemIndex-_leftItemIndex);
    //记录左右对应的indicator宽度
    CGFloat leftIndicatorWidth = [self getIndicatorWidthWithTitle:_childTitles[_leftItemIndex]];
    CGFloat rightIndicatorWidth = [self getIndicatorWidthWithTitle:_childTitles[_rightItemIndex]];
    
    //左右边界的时候，占比清0
    if(_leftItemIndex == _rightItemIndex) {
        relativeLocation = 0;
    }
    //基于从左到右方向（无需考虑滑动方向），计算当前中心轴所处位置的长度
    CGFloat nowIndicatorWidth = leftIndicatorWidth + (rightIndicatorWidth-leftIndicatorWidth)*relativeLocation;
    
    self.indicatorView.frame = CGRectMake(self.tabItemX + nowIndicatorCenterX-nowIndicatorWidth/2.0-_tabView.contentOffset.x, ORIGIN_Y(self.indicatorView), nowIndicatorWidth, HEIGHT(self.indicatorView));
    
    if (self.title_BG) {
        self.title_BG.frame = CGRectMake( nowIndicatorCenterX - (nowIndicatorWidth + 30)  / 2.0 - _tabView.contentOffset.x, ORIGIN_Y(self.title_BG), nowIndicatorWidth +  30, HEIGHT(self.title_BG));
    }
}

- (void)changeIndicatorFrameByStretch {
    if(_indicatorWidth <= 0) {
        return;
    }
    
    //计算此时body的偏移量在一页中的占比
    CGFloat relativeLocation = (self.bodyView.contentOffset.x/WIDTH(self.bodyView)-_leftItemIndex)/(_rightItemIndex-_leftItemIndex);
    //左右边界的时候，占比清0
    if(_leftItemIndex == _rightItemIndex) {
        relativeLocation = 0;
    }
    
    TT_PageTabItemLable *leftTabItem = _tabItems[_leftItemIndex];
    TT_PageTabItemLable *rightTabItem = _tabItems[_rightItemIndex];
    
    //当前的frame
    CGRect nowFrame = CGRectMake(0, ORIGIN_Y(self.indicatorView), 0, HEIGHT(self.indicatorView));
    
    //计算宽度
    if(relativeLocation <= 0.5) {
        nowFrame.size.width = _indicatorWidth+_tabItemWidth*(relativeLocation/0.5);
        nowFrame.origin.x = (self.tabItemX +leftTabItem.center.x-self.tabView.contentOffset.x)-_indicatorWidth/2.0;
    } else {
        nowFrame.size.width = _indicatorWidth+_tabItemWidth*((1-relativeLocation)/0.5);
        nowFrame.origin.x = (self.tabItemX + rightTabItem.center.x-self.tabView.contentOffset.x)+_indicatorWidth/2.0-nowFrame.size.width;
    }
    
    self.indicatorView.frame = nowFrame;
}

#pragma mark - Tool
/**
 根据对应文本计算下标线宽度
 */
- (CGFloat)getIndicatorWidthWithTitle:(NSString *)title {
    if(_indicatorStyle == TT_PageTabIndicatorStyleDefault || _indicatorStyle == TT_PageTabIndicatorStyleStretch) {
        return _indicatorWidth;
    } else {
        if(title.length <= 2) {
            return 40;
        } else {
            return title.length * _tabItemFont.pointSize + 12;
        }
    }
}

/**
 获取color的rgb值
 */
- (NSArray *)getRGBWithColor:(UIColor *)color {
    CGFloat R = 0.0, G = 0.0, B = 0.0;
    NSInteger numComponents = CGColorGetNumberOfComponents(color.CGColor);
    if(numComponents == 4) {
        const CGFloat *components = CGColorGetComponents(color.CGColor);
        R = components[0];
        G = components[1];
        B = components[2];
    }
    return @[@(R), @(G), @(B)];
}

#pragma mark - Getter/setter
- (UIView *)bgView {
    if(!_bgView) {
        _bgView = [UIView new];
    }
    return _bgView;
}

- (UIScrollView *)tabView {
    if(!_tabView) {
        _tabView = [UIScrollView new];
        _tabView.showsVerticalScrollIndicator = NO;
        _tabView.showsHorizontalScrollIndicator = NO;
        _tabView.backgroundColor = _tabBackgroundColor;
        _tabView.delegate = self;
        _tabView.clipsToBounds = YES;
    }
    return _tabView;
}

- (UIScrollView *)bodyView {
    if(!_bodyView) {
        _bodyView = [UIScrollView new];
        _bodyView.pagingEnabled = YES;
        _bodyView.showsVerticalScrollIndicator = NO;
        _bodyView.showsHorizontalScrollIndicator = NO;
        _bodyView.delegate = self;
        _bodyView.bounces = _bodyBounces;
        _bodyView.backgroundColor = _bodyBackgroundColor;
    }
    return _bodyView;
}

- (UIView *)indicatorView {
    if(!_indicatorView) {
        _indicatorView = [UIView new];
        _indicatorView.backgroundColor = _selectedColor;
    }
    return _indicatorView;
}

- (void)setTabBackgroundColor:(UIColor *)tabBackgroundColor {
    _tabBackgroundColor = tabBackgroundColor;
    self.tabView.backgroundColor = _tabBackgroundColor;
}

- (void)setBodyBackgroundColor:(UIColor *)bodyBackgroundColor {
    _bodyBackgroundColor = bodyBackgroundColor;
    self.bodyView.backgroundColor = _bodyBackgroundColor;
}

- (void)setSelectedTabIndex:(NSInteger)selectedTabIndex {
    if(selectedTabIndex >= 0 && selectedTabIndex < _numberOfTabItems && _selectedTabIndex != selectedTabIndex) {
        [self changeSelectedItemToNextItem:selectedTabIndex];
        _selectedTabIndex = selectedTabIndex;
        _lastSelectedTabIndex = selectedTabIndex;
        [self layoutIndicatorViewWithStyle];
        self.bodyView.contentOffset = CGPointMake(WIDTH(self)*_selectedTabIndex, 0);
        
        if(_titleStyle == TT_PageTabTitleStyleGradient) {
            [self resetTabItemScale];
        }
    }
}

- (void)setUnSelectedColor:(UIColor *)unSelectedColor {
    _unSelectedColor = unSelectedColor;
    for(NSInteger i = 0; i < _numberOfTabItems; i++) {
        TT_PageTabItemLable *tabItem = _tabItems[i];
        tabItem.textColor = i==_selectedTabIndex?_selectedColor:_unSelectedColor;
    }
    NSArray *rgb = [self getRGBWithColor:_unSelectedColor];
    _unSelectedColorR = [rgb[0] floatValue];
    _unSelectedColorG = [rgb[1] floatValue];
    _unSelectedColorB = [rgb[2] floatValue];
}

- (void)setSelectedColor:(UIColor *)selectedColor {
    _selectedColor = selectedColor;
    TT_PageTabItemLable *tabItem = _tabItems[_selectedTabIndex];
    tabItem.textColor = _selectedColor;
    self.indicatorView.backgroundColor = _selectedColor;
    NSArray *rgb = [self getRGBWithColor:_selectedColor];
    _selectedColorR = [rgb[0] floatValue];
    _selectedColorG = [rgb[1] floatValue];
    _selectedColorB = [rgb[2] floatValue];
}

- (void)setBodyBounces:(BOOL)bodyBounces {
    _bodyBounces = bodyBounces;
    self.bodyView.bounces = _bodyBounces;
}

- (void)setTabItemFont:(UIFont *)tabItemFont {
    _tabItemFont = tabItemFont;
    for(NSInteger i = 0; i < _numberOfTabItems; i++) {
        TT_PageTabItemLable *tabItem = _tabItems[i];
        tabItem.font = _tabItemFont;
    }
}

- (void)setTitleStyle:(TT_PageTabTitleStyle)titleStyle {
    if(_titleStyle == TT_PageTabTitleStyleDefault) {
        _titleStyle = titleStyle;
        if(_titleStyle == TT_PageTabTitleStyleGradient) {
            [self resetTabItemScale];
        }
    }
}

- (void)setIndicatorStyle:(TT_PageTabIndicatorStyle)indicatorStyle {
    if(_indicatorStyle == TT_PageTabIndicatorStyleDefault) {
        _indicatorStyle = indicatorStyle;
        [self addIndicatorViewWithStyle];
    }else if (_indicatorStyle == TT_PageTabIndicatorStyleBg) {
        _indicatorStyle = indicatorStyle;
        [self addIndicatorViewWithStyle];
    }
}

- (void)setMinScale:(CGFloat)minScale {
    if(minScale > 0 && minScale <= 1) {
        _minScale = minScale;
        if(_titleStyle == TT_PageTabTitleStyleGradient) {
            [self resetTabItemScale];
        }
    }
}
- (UILabel *)bottomLive {
    if (!_bottomLive) {
        _bottomLive = [[UILabel alloc]init];
        _bottomLive.backgroundColor = [UIColor lightGrayColor];
    }
    return _bottomLive;
}

- (UIView *)title_BG {
    if (!_title_BG) {
        _title_BG = [[UIView alloc]init];
        _title_BG.backgroundColor = _title_BGColor;
    }
    return _title_BG;
}

- (void)setIs_bodyScroll:(BOOL)is_bodyScroll {
    self.bodyView.scrollEnabled = is_bodyScroll;
}


@end