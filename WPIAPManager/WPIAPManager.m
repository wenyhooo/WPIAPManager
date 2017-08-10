//
//  WPIAPManager.m
//  WPIAPDemo
//
//  Created by liwenhao on 2017/8/9.
//  Copyright © 2017年 liwenhaopro. All rights reserved.
//

#import "WPIAPManager.h"
#import "WPIAPHelper.h"
#import <UICKeyChainStore/UICKeyChainStore.h>
#import <StoreKit/StoreKit.h>

#ifdef DEBUG
#define WPIAPlog(...) NSLog(__VA_ARGS__)
#else
#define WPIAPlog(...)
#endif

#define WPIAPReceiptKey [[NSBundle mainBundle]bundleIdentifier]
#define WPIAPOrderKey [NSString stringWithFormat:@"%@order",WPIAPReceiptKey]

@interface WPIAPManager ()

@property(nonatomic, strong) NSMutableDictionary *skProductDic;

@property(nonatomic, strong) WPIAPHelper *iapHelper;

@property(nonatomic, copy) WPbuyIapSuccessBlock buySuccessBlock;

@property(nonatomic, copy) void (^buyFailBlock)(NSError *error);
@end

@implementation WPIAPManager

+ (WPIAPManager *)sharedManager
{
    static WPIAPManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[WPIAPManager alloc] init];
    });
    return manager;
}

#pragma mark - public 检查历史一流订单
/**
 检查是否有历史充值问题
 @param resumBlock 如果有订单恢复  会回调
 */
- (void)appLaunchCheckresumeAppleServiceIAP:(WPbuyIapSuccessBlock)resumBlock
{
    BOOL isResum = [self checklocalityCacheHistoryIAPOrderResumBlock:resumBlock];
    if (!isResum) {
        __weak __typeof(self)weakSelf = self;
        [self.iapHelper resumeUnfinishedPaymentState:^(SKPaymentTransaction *transaction) {
            WPIAPlog(@"iap---检查有未结束订单,从apple service中恢复");
            [weakSelf disposePayTranscationState:transaction];
        }];
    }
}

/**
 iap购买
 @param productIdfier 商品ID
 @param orderDic  携带的订单信息 会随着购买凭证存入KeyChain,
 @param buySuccessBlock 购买成功后 需要向自己服务端验证 成功后要手动调用   cleanAppleOrderInfo
 @param buyFailBlock 购买失败
 */
- (void)buyAppleWithSKProductIdfier:(NSString *)productIdfier withOrderDic:(NSDictionary *)orderDic buySuccessBlock:(WPbuyIapSuccessBlock)buySuccessBlock buyFailBlock:(void (^)(NSError *error))buyFailBlock
{
    __weak __typeof(self)weakSelf = self;
    [self searchAppleProduct:productIdfier searchSuccessBlock:^(SKProduct *skRroduct) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        if (!strongSelf) {
            return ;
        }
        [strongSelf buyAppleWithSKProduct:skRroduct withOrderDic:orderDic buySuccessBlock:buySuccessBlock buyFailBlock:buyFailBlock];
    } failBlock:buyFailBlock];
}

/**
 iap购买
 @param productIdfier 商品ID
 @param orderDic  携带的订单信息 会随着购买凭证存入KeyChain,
 @param buySuccessBlock 购买成功后 需要向自己服务端验证 成功后要手动调用   cleanAppleOrderInfo
 @param buyFailBlock 购买失败
 */
- (void)buyAppleWithSKProduct:(SKProduct *)skProduct withOrderDic:(NSDictionary *)orderDic buySuccessBlock:(WPbuyIapSuccessBlock )buySuccessBlock buyFailBlock:(void (^)(NSError *error))buyFailBlock
{
    BOOL isResum = [self checklocalityCacheHistoryIAPOrderResumBlock:buySuccessBlock];
    if (isResum) {
        return ;
    }
    _buySuccessBlock = buySuccessBlock;
    _buyFailBlock = buyFailBlock;
    
    //存下订单信息
    NSString *orderString = [self dictionaryToJson:orderDic];
    [UICKeyChainStore setString:orderString forKey:WPIAPOrderKey];
    
    __weak __typeof(self)weakSelf = self;
    [self.iapHelper buyProduct:skProduct paymentState:^(SKPaymentTransaction *transaction) {
        [weakSelf disposePayTranscationState:transaction];
    }];
}

/**
 订单验证成功后或者认定丢弃 调用
 */
+ (void)cleanAppleOrderInfo
{
    [UICKeyChainStore removeItemForKey:WPIAPReceiptKey];
    [UICKeyChainStore removeItemForKey:WPIAPOrderKey];
}

/**
 去苹果服务器查询商品
 @param productIdfier 商品ID
 @param searchSuccessBlock 查询成功
 @param failBlock 查询失败
 */
- (void)searchAppleProduct:(NSString *)productIdfier searchSuccessBlock:(void (^)(SKProduct *skRroduct))searchSuccessBlock failBlock:(void (^)(NSError *error))failBlock
{
    SKProduct *skProduct = self.skProductDic[productIdfier];
    if (skProduct) {
        !searchSuccessBlock? :searchSuccessBlock(skProduct);
        return;
    }
    
    NSSet *productIdentifiers = [NSSet setWithObject:productIdfier];
    
    __weak __typeof(self)weakSelf = self;
    
    [self.iapHelper loadProductsWithIdentifiers:productIdentifiers successBlock:^(NSArray<SKProduct *> *productList) {
        NSMutableDictionary *dic = [NSMutableDictionary new];
        
        for (SKProduct *skProduct in productList) {
            dic[skProduct.productIdentifier] = skProduct;
        }
        [weakSelf.skProductDic setDictionary:dic];
        SKProduct *skProduct = self.skProductDic[productIdfier];
        !searchSuccessBlock? :searchSuccessBlock(skProduct);
    } errorBlock:failBlock];
}

/**
 去苹果服务器查询商品
 @param productIdfierList 商品ID list
 @param searchSuccessBlock 查询成功
 @param failBlock 查询失败
 */
- (void)searchAppleProductList:(NSSet *)productIdfierList searchSuccessBlock:(void (^)(NSArray<SKProduct *> *skRroduct))searchSuccessBlock failBlock:(void (^)(NSError *error))failBlock
{
    __weak __typeof(self)weakSelf = self;
    
    [self.iapHelper loadProductsWithIdentifiers:productIdfierList successBlock:^(NSArray<SKProduct *> *productList) {
        NSMutableDictionary *dic = [NSMutableDictionary new];
        
        for (SKProduct *skProduct in productList) {
            dic[skProduct.productIdentifier] = skProduct;
        }
        [weakSelf.skProductDic setDictionary:dic];
        !searchSuccessBlock? :searchSuccessBlock(productList);
    } errorBlock:failBlock];
}

#pragma mark - SKPaymentTransactionObserver
//购买过程中的回调处理
- (void)disposePayTranscationState:(SKPaymentTransaction *)transaction
{
    switch (transaction.transactionState)
    {
        case SKPaymentTransactionStatePurchasing:
            WPIAPlog(@"iap---正在付款");
            break;
            
        case SKPaymentTransactionStateDeferred:
            WPIAPlog(@"iap---正在延迟");
            break;
            
        case SKPaymentTransactionStatePurchased:{
            WPIAPlog(@"iap---付款完成");
            [self productPayed:transaction];
        }
            break;
            
        case SKPaymentTransactionStateFailed:
            WPIAPlog(@"iap---付款失败-->%@", transaction.error.localizedDescription);
            [self productPayFailed:transaction];
            break;
            
        case SKPaymentTransactionStateRestored:
            WPIAPlog(@"iap---付款已恢复");
            [self productPayed:transaction];
            break;
            
        default:
            break;
    }
}

#pragma mark - action - 购买成功
- (void)productPayed:(SKPaymentTransaction *)transaction
{
    NSString *receiptString = [self receiptString];
    
    if (receiptString) {
        //此时正确购买，保存该凭证
        [UICKeyChainStore setString:receiptString forKey:WPIAPReceiptKey];
    } else {
        //此时恢复出错，尝试从 keyChain 中恢复
        receiptString = [UICKeyChainStore stringForKey:WPIAPReceiptKey];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    NSDictionary *orderDic = [self orderDic];
    !_buySuccessBlock? :_buySuccessBlock(orderDic,receiptString);
}

#pragma mark - action - 购买失败
- (void)productPayFailed:(SKPaymentTransaction *)transaction
{
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    !_buyFailBlock? :_buyFailBlock(transaction.error);
}

#pragma mark - geter
- (WPIAPHelper *)iapHelper
{
    if (!_iapHelper) {
        _iapHelper = [[WPIAPHelper alloc] init];
    }
    return _iapHelper;
}

- (NSMutableDictionary *)skProductDic
{
    if (!_skProductDic) {
        _skProductDic = [NSMutableDictionary new];
    }
    return _skProductDic;
}

#pragma mark - pravite

/**
 检查本地cache是否有历史充值问题,有充值未到账的
 @param resumBlock 如果有订单恢复  会回调
 @return yes/no  有无历史单子
 */
- (BOOL)checklocalityCacheHistoryIAPOrderResumBlock:(WPbuyIapSuccessBlock)resumBlock
{
    NSString *receiptString = [UICKeyChainStore stringForKey:WPIAPReceiptKey];
    NSString *orderString = [UICKeyChainStore stringForKey:WPIAPOrderKey];
    
    NSDictionary *orderDic = [self dictionaryWithJsonString:orderString];
    if (receiptString && orderDic){
        WPIAPlog(@"iap---检查有未结束订单,从沙盒中恢复");
        !resumBlock? :resumBlock(orderDic,receiptString);
        return YES;
    }
    return NO;
}

- (NSString *)receiptString
{
    NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *receiptString = [data base64EncodedStringWithOptions:0];
    return receiptString;
}
- (NSDictionary *)orderDic
{
    NSString *orderString = [UICKeyChainStore stringForKey:WPIAPOrderKey];
    NSDictionary *orderDic = [self dictionaryWithJsonString:orderString];
    return orderDic;
}

- (NSString*)dictionaryToJson:(NSDictionary *)dic
{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (NSDictionary *)dictionaryWithJsonString:(NSString *)jsonString
{
    if (jsonString == nil){
        return nil;
    }
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    NSError *err;
    NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                        options:NSJSONReadingMutableContainers
                                                          error:&err];
    if(err) {
        WPIAPlog(@"iap---json解析失败：%@",err);
        return nil;
    }
    return dic;
}


@end
