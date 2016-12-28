#新闻详情页排版实现
　　不论是哪一家新闻app的新闻详情页都有大量的图片和片断性的文字，一直很好奇它排版的具体实现方式，构想过一些办法（富文本之类）发现都不是明智的方法，所以决定研究一下。  
　　查阅资料得知新闻页面大都是用UIWebView加载html来完成。参考博文[网易新闻客户端iOS版本中新闻详情页（UIWebView）技术实现的分析探讨](http://386502324.blog.163.com/blog/static/11346937720154293438399/)的内容以及作者的demo我也实现了一遍。  
###涉及的技术点：  
　　* html模板引擎的使用，我使用的[GRMustache](https://github.com/groue/GRMustache)。   
　　* JS与OC之间的通信，可以使用[WebViewJavascriptBridge](https://github.com/marcuswestin/WebViewJavascriptBridge)。    
　　* SDWebImage的使用，这里指的主要是指下载图片，返回已经下载完成的图片在本地的地址。  
　　ps:需要一点点html和js语法上的知识，如果不懂我觉得靠google/baidu也是能够搞定的。  
　　
###效果  
　　原谅我偷懒，没有自己去抓数据，是参照[网易新闻客户端iOS版本中新闻详情页（UIWebView）技术实现的分析探讨](http://386502324.blog.163.com/blog/static/11346937720154293438399/)这篇博文里作者抓取的链接来完成demo,我这篇其实就是这个博文的稍微啰嗦一点的版本。  
![](http://ac-3xs828an.clouddn.com/769029710c3f2e11b736.gif)  
  
###主要实现  
1.WebViewJavascriptBridge的初始化  
 
```objective-c
- (void)initBridge {
    // 开启日志
    [WebViewJavascriptBridge enableLogging];
    
    //设置给哪个webView建立js与oc通信的桥梁
    self.bridge = [WebViewJavascriptBridge bridgeForWebView:self.webView];
    //如果需要实现UIWebViewDelegate可以设置代理
    [self.bridge setWebViewDelegate:self];
    
    //注册 用于js主动调用oc
    [self.bridge registerHandler:@"testObjcCallback" handler:^(id data, WVJBResponseCallback responseCallback) {
        NSLog(@"我是js主动调用oc后的输出");
    }];
    
    //注册图片点击事件
    __weak typeof(self)weakSelf = self;
    [self.bridge registerHandler:@"tapImage" handler:^(id data, WVJBResponseCallback responseCallback) {
    	//点击图片的index
        NSLog(@"=======%@=========", data);
        NSString *index = (NSString *)data;
        //初始化图片浏览器
        [weakSelf browseImages:index.integerValue];
    }];
    
    //oc主动调用js
    [self.bridge callHandler:@"testJavascriptHandler" data:nil responseCallback:^(id responseData) {
        NSLog(@"我是oc主动调用js后的输出");
    }];
}
```  
　　关于WebViewJavascriptBridge的使用，一开始看着回调的使用可能会有点晕，特别是之前的版本中，调用可以通过`send`和`callHandler `两种方法，最近的版本中好像已经只采用`callHandler `这一种方法来进行调用了，简化了理解。  
　　其实简单来说就是一个注册&调用的关系。如果js需要调用oc的代码，那么js是主动方，用`callHandler `方法，即调用的字面意思。而oc是被调用的一方，需要注册一个方法用于被调用，即用`registerHandler`方法，反过来oc调用js是一样的。  
　　可以通过[UIWebView与JS的深度交互](http://kittenyang.com/webview-javascript-bridge/)这篇文章进行理解。不过最近的版本中已经没有再采用`send`的方法来调用了。  

2.网络请求　　

```objective-c
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
```  
　　这里的使用应该没有问题，就是利用AFN进行网络请求，请求成功后对返回的json进行处理。  

3.返回数据的简单分析  
　　* 返回的字段  

```json
{
	AQ4RPLHG00964LQ9: {
		body: "<p></p>",
		users: [ ],
		ydbaike: [ ],
		replyCount: 12550,
		link: [ ],
		img: [],
		votes: [],
		shareLink: "https://c.m.163.com/news/a/	AQ4RPLHG00964LQ9.html?spss=newsapp&spsw=1",
			digest: "",
		topiclist_news: [ ],
		dkeys: "轻松一刻",
		topiclist: [ ],
		docid: "AQ4RPLHG00964LQ9",
		picnews: true,
		title: "每日轻松一刻（5月21日午间)",
		tid: "",
		template: "special",
		threadVote: 12,
		rewards: [],
		threadAgainst: 5,
		boboList: [ ],
		replyBoard: "3g_bbs",
		source: "网易新媒体",
		hasNext: false,
		voicecomment: "off",
		ptime: "2015-05-21 11:14:01"
		}
}
```  
　　这里是返回的全部字段，具体的字段值我进行了省略，因为太长了。下面着重看`body`和`img`字段。  
　　* `body`  

```json
<p>说好的，521继续虐狗！来点刺激的！</p>
<!--IMG#0-->
<p>什么小年轻秀恩爱都俗透了，不是经常被骂分得快么，要玩就玩大的，彼此都老了是种啥感觉？</p>
<p>这对20多岁的情侣被化妆成50、70、90岁的模样，老湿的小心脏。。。</p>
<!--IMG#1-->
<!--IMG#2-->
<!--IMG#3--><p>一夜变老，这酸爽，比熬了几个大黑夜还见效！</p>
```  
　　这里我只是选取了部分`body`的值，但是已经可以发现规律了，有大量的`<!--IMG#？-->`这种形式的文本掺杂在其中，这其实就是图片的占位符，每个占位符都不相同，即对应着不同的图片。下面看`img`的字段值就能理解了。  
　　
* `img`  

```json
img: [
	{
	ref: "<!--IMG#0-->",
	pixel: "550*767",
	alt: "",
	src: "http://img5.cache.netease.com/m/2015/5/21/20150521105913d3770_550.jpg"
	},
	{
	ref: "<!--IMG#1-->",
	pixel: "356*201",
	alt: "",
	src: "http://img3.cache.netease.com/m/2015/5/21/201505211111290babf.gif"
	},
	......
]
```  
　　可以看出来，`img`数组每个元素中都有一个`ref`字段，这个值是与上方`body`中的一一对应的，图片的尺寸、url都在`img`的元素中给出了，下一步就是拿到通过`img`元素给出的图片信息来组成html文本替换`body`中图片的占位符。  

4.body中图片占位符以html格式文本来替换
  
```objective-c
- (NSMutableString *)handleImageInNews:(DataInfo *)data {
    NSMutableString *bodyStr = [data.body mutableCopy];
    
    [data.img enumerateObjectsUsingBlock:^(ImageInfo *info, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [bodyStr rangeOfString:info.ref];
        NSArray *wh = [info.pixel componentsSeparatedByString:@"*"];
        CGFloat width = [[wh objectAtIndex:0] floatValue];
        CGFloat height = [[wh objectAtIndex:1] floatValue];
        
        //占位图
        NSString *loadingImg = [[NSBundle mainBundle] pathForResource:@"loading" ofType:@"png"];
        NSString *imageStr = [NSString stringWithFormat:@"<p style = 'text-align:center'><img onclick = 'didTappedImage(%lu);' src = %@ id = '%@' width = '%.0f' height = '%.0f' hspace='0.0' vspace ='5' style ='width:60%%;height:60%%;' /></p>", (unsigned long)idx, loadingImg, info.src, width, height];
        [bodyStr replaceOccurrencesOfString:info.ref withString:imageStr options:NSCaseInsensitiveSearch range:range];
    }];

    [self getImageFromDownloaderOrDiskByImageUrlArray:data.img];
    
    return bodyStr;
}
```  
　　通过图片的`ref`字段，一一用html格式的文本来替换`body`中对应的图片的占位文本，如`<!--IMG#0-->`将被替换为如下:

```html
<p style = 'text-align:center'><img onclick = 'didTappedImage(0);' src = /Users/yiban/Library/Developer/CoreSimulator/Devices/25D5A6D1-94EB-4C29-8FF4-3158CC846935/data/Containers/Bundle/Application/E67999A2-27B2-4C4D-A137-1D2B56241B61/WebHtmlLoad.app/loading.png id = 'http://img5.cache.netease.com/m/2015/5/21/20150521105913d3770_550.jpg' width = '550' height = '767' hspace='0.0' vspace ='5' style ='width:80%;height:80%;' /></p>
```
　　这里有一个`loadingImg `,是本地一张图片，用来作为图片未下载完成时的loading图。新闻中的图片根据url下载完成后找到该图片在本地的地址替换掉html文本中`src`的值，即替换掉占位图的地址。  

5.拼接html格式的标题  

```objective-c
- (NSMutableString *)handleNewsTitle:(DataInfo *)data {
    NSMutableString *htmlTitleStr = [NSMutableString stringWithString:@"<style type='text/css'> p.thicker{font-weight: 900}p.light{font-weight: 0}p{font-size: 108%}h2 {font-size: 120%}h3 {font-size: 80%}</style> <h2 class = 'thicker'>{{title}}</h2><h3>{{source}} {{ptime}}</h3>"];
    return [[GRMustacheTemplate renderObject:@{@"title" : data.title, @"source" : data.source, @"ptime" : data.ptime} fromString:htmlTitleStr error:NULL] mutableCopy];
}
```  
　　这里的html文本中出现了双大括号`{{xxx}}`的写法，其实这是html模板引擎`GRMustache`的语法。我这里只使用了它最基本的一个用法，用`{{}}`包住你想要替换的占位文本，然后在一个字典内用相同的占位文本作为key给html赋值。模板引擎的使用可以很优雅的实现这种文本值的替换填充，如果不适用模板引擎上面的代码如下:  

```objective-c
- (NSMutableString *)handleNewsTitle:(DataInfo *)data {
    NSMutableString *htmlTitleStr = [NSMutableString stringWithString:@"<style type='text/css'> p.thicker{font-weight: 900}p.light{font-weight: 0}p{font-size: 108%}h2 {font-size: 120%}h3 {font-size: 80%}</style> <h2 class = 'thicker'>title</h2><h3>source ptime </h3>"];
    [htmlTitleStr replaceOccurrencesOfString:@"title" withString:data.title options:NSCaseInsensitiveSearch range:[htmlTitleStr rangeOfString:@"title"]];
    [htmlTitleStr replaceOccurrencesOfString:@"source" withString:data.source options:NSCaseInsensitiveSearch range:[htmlTitleStr rangeOfString:@"source"]];
    [htmlTitleStr replaceOccurrencesOfString:@"ptime" withString:data.ptime options:NSCaseInsensitiveSearch range:[htmlTitleStr rangeOfString:@"ptime"]];
    
    return htmlTitleStr;
}
```  
　　有很多重复的`replaceOccurrencesOfString`，如果需要替换的文本很多时，感觉是在做大量的重复工作，所以这种时候就适用模板引擎，能够更优雅的实现替换值。  

6.图片缓存  

```objective-c
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
```  
　　这里涉及到的主要技术点就是图片的缓存、缓存的本地路径获取、用WebViewJavascriptBridge向js发送消息。图片这一块就不再赘述了，大家应该都能掌握，那就稍微解释一下`callHandler`。  
　　程序成功下载并获得图片的缓存路径是在oc代码里，我们希望获取的图片能在html代码里加载，这就需要oc告诉js图片的路径，所以是oc主动调用js代码，用`callHandler`方法。`replaceImage`是用来标识一个方法，调用js里用`replaceImage`注册的方法。`sendData`是oc想要传给js的参数，参数的值是`repalceImage`+`图片的url`+ `,` +`图片的本地路径`。在第四点中我们用html格式文本来替换图片占位符时，html文本的`img`是用url作为`id`的，所以这里传入图片的url是为了能在js中根据这个url获取到指定的图片`img`,`img`的`src`真正的值是这里传过去的本地路径。  

7.js代码  

```JavaScript
function didTappedImage(index) {
    setupWebViewJavascriptBridge(function(bridge) {
                                 bridge.callHandler('tapImage', index,
                                                    function(response) {})
                                 })
}

bridge.registerHandler('replaceImage', function(data, responseCallback) {
                                                        if (data.match("replaceimage")) {
                                                            var index = data.indexOf(",")
                                                            var messageReplace = data.substring(0, index)
                                                            var messagePath = data.substring(index+1)
                                                            messageReplace = messageReplace.replace(/replaceimage/, "")
                                                            element = document.getElementById(messageReplace)
                                                            if (element.src.match("loading")) {
                                                                responseCallback(messagePath)
                                                                element.src = messagePath
                                                            }
                                                        }
                                                        })
```
　　js除去语法层面，最主要的就是了解`WebViewJavascriptBridge`的用法。图片路径的替换，看代码就能理解了，一共也没几句呢。图片的点击事件，在图片的html代码里有写到`onclick = 'didTappedImage(%lu);'`,参数是图片的序号，用于图片浏览器能定位到当前点击的图片。这里需要在js里有一个方法，用来供点击事件的时候调用，这个方法又要用来调用oc代码，所以是html里的图片点击触发一个事件调用js函数，js函数需要告诉oc发生了这件事，是js主动调用oc代码，js里用`bridge.callHandler`。需要注意的是，因为这是oc和js通信的代码，必须写在`setupWebViewJavascriptBridge`的`callback`里，不然调用不起作，属于`WebViewJavascriptBridge`的一些用法。  
　　
###写在最后  
　　写这篇demo不是一帆风顺的，遇到一个神坑，折腾了好久。我用CocoaPods下载`WebViewJavascriptBridge`, 然后去它的git上下载demo，想看看demo的使用，然后拷贝demo里的html文件到自己项目里修改功能，结果死活没法让oc和js互相调用，然而各种检查发现都没有错。最后，我把demo里`WebViewJavascriptBridge`的文件夹拖过来，删掉了CocoaPods下载的版本，于是世界和平。。。  
　　　　代码我已经是各种精简了，命名什么的也尽力准确，希望大家理解起来能比较顺利。
　　
　　
