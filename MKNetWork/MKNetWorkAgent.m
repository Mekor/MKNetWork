//
//  MKNetWorkAgent.m
//  NetWorkDemo
//
//  Created by Mekor on 8/2/16.
//  Copyright © 2016 李小争. All rights reserved.
//

#import "MKNetWorkAgent.h"
#import <AFNetWorking.h>
#import "MKBaseRequest.h"
#import "MKNetworkConfig.h"

@implementation MKNetWorkAgent {
    AFHTTPSessionManager *_manager;///< SessionManager
    NSMutableDictionary<NSNumber *, NSURLSessionDataTask *> *_requestsRecord;///< 请求列表
    MKNetworkConfig *_config;
}

+ (MKNetWorkAgent *)sharedInstance {
    static id sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        // 配置初始化
        _config = [MKNetworkConfig sharedInstance];
        
        // 实例化 AFHTTPSessionManager
        _manager = [AFHTTPSessionManager manager];
        _manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        _manager.securityPolicy.allowInvalidCertificates = YES;
        _manager.securityPolicy.validatesDomainName = NO;
        _manager.securityPolicy = _config.securityPolicy;
        // 实例化 requestsRecord
        _requestsRecord = [NSMutableDictionary dictionary];
        
    }
    return self;
}

#pragma mark 添加网络请求
- (void)addRequest:(MKBaseRequest *)baseRequest {
    NSLog(@"\n==================================\n\nRequest Start: \n\n "
          @"%@\n\n==================================",
          [baseRequest requestUrl]);
    
    
    MKRequestMethod method = [baseRequest requestMethod];
    NSString *url = [self buildRequestUrl:baseRequest];
    id param = [baseRequest.paramSource paramsForRequest:baseRequest];
    
    AFHTTPRequestSerializer *requestSerializer = nil;
    if (baseRequest.requestSerializerType == MKRequestSerializerTypeHTTP) {
        requestSerializer = [AFHTTPRequestSerializer serializer];
    } else if (baseRequest.requestSerializerType == MKRequestSerializerTypeJSON) {
        requestSerializer = [AFJSONRequestSerializer serializer];
    }
    requestSerializer.timeoutInterval = [baseRequest requestTimeoutInterval];
    requestSerializer.cachePolicy = NSURLRequestUseProtocolCachePolicy;
    
    NSURLRequest *request = nil;
    switch (method) {
        case MKRequestMethodGet:
            request = [self generateRequestWithUrlString:url Params:param methodName:@"GET" serializer:requestSerializer];
            break;
        case MKRequestMethodPost:
            request = [self generateRequestWithUrlString:url Params:param methodName:@"POST" serializer:requestSerializer];
            break;
        case MKRequestMethodHead:
            request = [self generateRequestWithUrlString:url Params:param methodName:@"HEAD" serializer:requestSerializer];
            break;
        case MKRequestMethodPut:
            request = [self generateRequestWithUrlString:url Params:param methodName:@"PUT" serializer:requestSerializer];
            break;
        case MKRequestMethodDelete:
            request = [self generateRequestWithUrlString:url Params:param methodName:@"DELETE" serializer:requestSerializer];
            break;
        case MKRequestMethodPatch:
            request = [self generateRequestWithUrlString:url Params:param methodName:@"PATCH" serializer:requestSerializer];
            break;
            
        default:
            request = [self generateRequestWithUrlString:url Params:param methodName:@"POST" serializer:requestSerializer];
            break;
    }
    
    // 跑到这里的block的时候，就已经是主线程了。
    __block NSURLSessionDataTask *dataTask = nil;
    
    dataTask = [_manager dataTaskWithRequest:request
                           completionHandler:^(NSURLResponse *_Nonnull response,
                                               id _Nullable responseObject,
                                               NSError *_Nullable error)
    {
        NSNumber *requestID = @([dataTask taskIdentifier]);
        baseRequest.requestID = requestID;
        baseRequest.responseObject = responseObject;
        
        [_requestsRecord removeObjectForKey:requestID];
        
        if (error) {
            if(baseRequest.delegate != nil){
                [baseRequest.delegate requestFailed:baseRequest];
            }
        } else {
            // 检查http response是否成立。
            if(baseRequest.delegate != nil){
                [baseRequest.delegate requestFinished:baseRequest];
            }
        }
    }];
    // 添加到请求列表
    NSNumber *requestId = @([dataTask taskIdentifier]);
    NSLog(@"获取到requestId");
    _requestsRecord[requestId] = dataTask;
    [dataTask resume];
}

#pragma mark 取消网络请求
-(void)cancelRequest:(NSNumber *)requestID {
    NSURLSessionDataTask *requestOperation = _requestsRecord[requestID];
    if (!requestOperation) {
        return;
    }
    [requestOperation cancel];
    [_requestsRecord removeObjectForKey:requestID];
}


#pragma mark - 生成request
- (NSURLRequest *)generateRequestWithUrlString:(NSString *)url Params:(NSDictionary *)requestParams methodName:(NSString *)methodName serializer:(AFHTTPRequestSerializer*)requestSerializer{
    
    
    NSMutableURLRequest *request = [requestSerializer requestWithMethod:methodName URLString:url parameters:requestParams error:NULL];
    [request setValue:@"123123" forHTTPHeaderField:@"xxxxxxxx"];

    return request;
}

#pragma mark 生成url
- (NSString *)buildRequestUrl:(MKBaseRequest*)request {
    NSString *detailUrl = [request requestUrl];
    if ([detailUrl hasPrefix:@"http"]) {
        return detailUrl;
    }
    
    // filter url
    NSArray *filters = [_config urlFilters];
    for (id<MKUrlFilterProtocol> f in filters) {
        detailUrl = [f filterUrl:detailUrl withRequest:request];
    }
    NSString *baseUrl;
    if ([request useCDN]) {
        if ([request cdnUrl].length > 0) {
            baseUrl = [request cdnUrl];
        } else {
            baseUrl = [_config cdnUrl];
        }
    } else {
        if ([request baseUrl].length > 0) {
            baseUrl = [request baseUrl];
        } else {
            baseUrl = [_config baseUrl];
        }
    }
    return [NSString stringWithFormat:@"%@%@", baseUrl, detailUrl];
}

@end
