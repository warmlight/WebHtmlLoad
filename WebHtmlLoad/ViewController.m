//
//  ViewController.m
//  WebHtmlLoad
//
//  Created by yiban on 16/12/22.
//  Copyright © 2016年 Lyy. All rights reserved.
//

#import "ViewController.h"
#import "WebViewJavascriptBridge.h"
#import "AFNetworking.h"
#import "GRMustache.h"
#import "DataInfo.h"
#import "ImageInfo.h"
#import "MJExtension.h"
#import "SDWebImageManager.h"
#import "MWPhotoBrowser.h"

@interface ViewController () <UIWebViewDelegate ,MWPhotoBrowserDelegate>
@property (strong, nonatomic) UIWebView *webView;
@property (strong, nonatomic) NSString *detailID;
@property (strong, nonatomic) NSMutableArray *imagesArr;
@property (strong, nonatomic) NSMutableArray *MWPhotoArr;
@property (strong, nonatomic) WebViewJavascriptBridge *bridge;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self initUI];
    [self initBridge];
    [self httpRequest];
}

- (void)initUI {
    self.view.backgroundColor = [UIColor whiteColor];
    self.webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.webView];
}

- (void)initBridge {
    // 开启日志
    [WebViewJavascriptBridge enableLogging];
    
    //设置给哪个webView建立js与oc通信的桥梁
    self.bridge = [WebViewJavascriptBridge bridgeForWebView:self.webView];
    //如果需要实现UIWebViewDelegate可以设置代理
    [self.bridge setWebViewDelegate:self];
    
    //注册 用于js主动调用oc
    [self.bridge registerHandler:@"testObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"我是js主动调用后的输出");
    }];
    
    //注册图片点击事件
    __weak typeof(self)weakSelf = self;
    [self.bridge registerHandler:@"tapImage" handler:^(id data, WVJBResponseCallback responseCallback) {
        //点击图片的index
        NSLog(@"=======%@=========", data);
        NSString *index = (NSString *)data;
        [weakSelf browseImages:index.integerValue];
    }];
    
    //oc主动调用js
    [self.bridge callHandler:@"testJavascriptHandler" data:nil responseCallback:^(id responseData) {
        NSLog(@"我是oc主动调用js后的输出");
    }];
}

//初始化图片浏览器
- (void)browseImages:(NSInteger)index {
    if (index >= self.imagesArr.count) {
        NSLog(@"图片index出错，越界");
    }
    
    self.MWPhotoArr = [NSMutableArray array];
    for (NSURL *url in self.imagesArr) {
        [self.MWPhotoArr addObject:[MWPhoto photoWithURL:url]];
    }
    
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    [browser setCurrentPhotoIndex:index];
    browser.zoomPhotosToFill = NO;
    browser.alwaysShowControls = YES;
    [self.navigationController pushViewController:browser animated:YES];
}

#pragma mark - MWPhotoBrowserDelegate
- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return self.MWPhotoArr.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    if (index < self.MWPhotoArr.count) {
        return [self.MWPhotoArr objectAtIndex:index];
    }
    return nil;
}

- (void)httpRequest {
    self.detailID = @"AQ4RPLHG00964LQ9";//多张图片
    NSMutableString *urlStr = [NSMutableString stringWithString:@"http://c.m.163.com/nc/article/xukunhenwuliao/full.html"];
    [urlStr replaceOccurrencesOfString:@"xukunhenwuliao" withString:_detailID options:NSCaseInsensitiveSearch range:[urlStr rangeOfString:@"xukunhenwuliao"]];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    
    __weak typeof(self)weakSelf = self;
    [manager GET:urlStr parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        DataInfo *model = [DataInfo mj_objectWithKeyValues:[responseObject objectForKey:self.detailID]];
        NSLog(@"请求成功");
        [weakSelf handleData:model];
             
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull   error) {
        NSLog(@"%@",error);  //这里打印错误信息
    }];
}

- (void)handleData:(DataInfo *)data {
    if (!data) {
        NSLog(@"返回数据错误");
        return;
    }

    NSMutableString *allTitleStr = [self handleNewsTitle:data];
    NSMutableString *bodyStr = [self handleImageInNews:data];

    NSString * str5 = [allTitleStr stringByAppendingString:bodyStr];
    NSString* htmlPath = [[NSBundle mainBundle] pathForResource:@"NewsHtml" ofType:@"html"];
    NSMutableString* appHtml = [NSMutableString stringWithContentsOfFile:htmlPath encoding:NSUTF8StringEncoding error:nil];
    [appHtml replaceOccurrencesOfString:@"<p>mainnews</p>" withString:str5 options:NSCaseInsensitiveSearch range:[appHtml rangeOfString:@"<p>mainnews</p>"]];
    NSURL *baseURL = [NSURL fileURLWithPath:htmlPath];
    [self.webView loadHTMLString:appHtml baseURL:baseURL];
}

//处理新闻body中的图片
- (NSMutableString *)handleImageInNews:(DataInfo *)data {
    NSMutableString *bodyStr = [data.body mutableCopy];
    
    [data.img enumerateObjectsUsingBlock:^(ImageInfo *info, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [bodyStr rangeOfString:info.ref];
        NSArray *wh = [info.pixel componentsSeparatedByString:@"*"];
        CGFloat width = [[wh objectAtIndex:0] floatValue];
        CGFloat height = [[wh objectAtIndex:1] floatValue];
        
        //占位图
        NSString *loadingImg = [[NSBundle mainBundle] pathForResource:@"loading" ofType:@"png"];
        NSString *imageStr = [NSString stringWithFormat:@"<p style = 'text-align:center'><img onclick = 'didTappedImage(%lu);' src = %@ id = '%@' width = '%.0f' height = '%.0f' hspace='0.0' vspace ='5' style ='width:80%%;height:80%%;' /></p>", (unsigned long)idx, loadingImg, info.src, width, height];
        [bodyStr replaceOccurrencesOfString:info.ref withString:imageStr options:NSCaseInsensitiveSearch range:range];

    }];

    [self getImageFromDownloaderOrDiskByImageUrlArray:data.img];
    
    return bodyStr;
}

//处理title的拼接显示
- (NSMutableString *)handleNewsTitle:(DataInfo *)data {
    NSString *htmlTitleStr = @"<style type='text/css'> p.thicker{font-weight: 900}p.light{font-weight: 0}p{font-size: 108%}h2 {font-size: 120%}h3 {font-size: 80%}</style> <h2 class = 'thicker'>{{title}}</h2><h3>{{source}} {{ptime}}</h3>";
    return [[GRMustacheTemplate renderObject:@{@"title" : data.title, @"source" : data.source, @"ptime" : data.ptime} fromString:htmlTitleStr error:NULL] mutableCopy];
}

- (void)getImageFromDownloaderOrDiskByImageUrlArray:(NSArray *)imageArray {
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    self.imagesArr = [NSMutableArray array];
    __weak typeof(self)weakSelf = self;
    for (ImageInfo *info in imageArray) {
        NSURL *imageUrl = [NSURL URLWithString:info.src];
        [self.imagesArr addObject:imageUrl];
        [imageManager diskImageExistsForURL:imageUrl completion:^(BOOL isInCache) {
            isInCache ? [weakSelf handleExistCache:imageUrl] : [weakSelf handleNotExistCache:imageUrl];
        }];
    }
}

//已经有图片缓存
- (void)handleExistCache:(NSURL *)imageUrl {
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    NSString *cacheKey = [imageManager cacheKeyForURL:imageUrl];
    NSString *imagePath = [imageManager.imageCache defaultCachePathForKey:cacheKey];
  
    NSString *sendData = [NSString stringWithFormat:@"replaceimage%@,%@", imageUrl.absoluteString, imagePath];
    [self.bridge callHandler:@"replaceImage" data:sendData responseCallback:^(id responseData) {
        NSLog(@"%@", responseData);
    }];
}

//本地没有图片缓存
- (void)handleNotExistCache:(NSURL *)imageUrl {
    SDWebImageManager *imageManager = [SDWebImageManager sharedManager];
    __weak typeof(self)weakSelf = self;
    
    [imageManager downloadImageWithURL:imageUrl options:0 progress:nil completed:^(UIImage *image, NSError *error, SDImageCacheType cacheType, BOOL finished, NSURL *imageURL) {
        if (image && finished) {
            NSLog(@"下载成功");
            [weakSelf handleExistCache:imageUrl];
        } else {
            NSLog(@"图片下载失败");
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
@end
