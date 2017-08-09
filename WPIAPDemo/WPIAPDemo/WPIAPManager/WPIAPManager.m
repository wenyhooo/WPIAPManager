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

#pragma mark - 检查历史一流订单

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
            [weakSelf disposePayTranscationState:transaction];
        }];
    }
}

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
        WPIAPlog(@"检查有未结束订单,从沙盒中恢复");
        !resumBlock? :resumBlock(orderDic,receiptString);
        return YES;
    }
    return NO;
}

/**
 iap购买
 @param productIdfier 商品ID
 @param orderDic  携带的订单信息 会随着购买凭证存入KeyChain,
 @param buySuccessBlock 购买成功
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
 订单验证成功后或者认定丢弃 调用
 */
- (void)cleanAppleOrderInfo
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
    }
    
    NSSet *productIdentifiers = [NSSet setWithObject:productIdfier];
    
    __weak __typeof(self)weakSelf = self;
    
    [self.iapHelper loadProductsWithIdentifiers:productIdentifiers successBlock:^(NSArray<SKProduct *> *productList) {
        NSMutableDictionary *dic = [NSMutableDictionary new];
        
        for (SKProduct *skProduct in productList) {
            dic[skProduct.productIdentifier] = skProduct;
        }
        [weakSelf.skProductDic setDictionary:dic];
        SKProduct *skProduct = self.skProductDic[productIdentifiers];
        !searchSuccessBlock? :searchSuccessBlock(skProduct);
    } errorBlock:failBlock];
}

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
    [UICKeyChainStore setString:orderString forKey:WPIAPReceiptKey];
    
    __weak __typeof(self)weakSelf = self;
    [self.iapHelper buyProduct:skProduct paymentState:^(SKPaymentTransaction *transaction) {
        [weakSelf disposePayTranscationState:transaction];
    }];
}

#pragma mark - action
//购买过程中的回调处理
- (void)disposePayTranscationState:(SKPaymentTransaction *)transaction
{
    WPIAPlog(@"苹果处理流程-->description =%@,transactionState = %ld", transaction.error.localizedDescription,(long)transaction.transactionState);
    switch (transaction.transactionState)
    {
        case SKPaymentTransactionStatePurchasing:
            WPIAPlog(@"正在付款");
            break;
            
        case SKPaymentTransactionStateDeferred:
            WPIAPlog(@"正在延迟");
            break;
            
        case SKPaymentTransactionStatePurchased:{
            WPIAPlog(@"付款完成");
            [self productPayed:transaction];
        }
            break;
            
        case SKPaymentTransactionStateFailed:
            WPIAPlog(@"付款失败-->%@", transaction.error.localizedDescription);
            [self productPayFailed:transaction];
            break;
            
        case SKPaymentTransactionStateRestored:
            WPIAPlog(@"付款已恢复");
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            break;
            
        default:
            break;
    }
}

#pragma mark - action - 购买成功
- (void)productPayed:(SKPaymentTransaction *)transaction
{
    NSURL *url = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *data = [NSData dataWithContentsOfURL:url];
    NSString *receiptString = [data base64EncodedStringWithOptions:0];
    
    if (receiptString) {
        //此时正确购买，保存该凭证
        [UICKeyChainStore setString:receiptString forKey:WPIAPReceiptKey];
    } else {
        //此时恢复出错，尝试从 keyChain 中恢复
        receiptString = [UICKeyChainStore stringForKey:WPIAPReceiptKey];
    }
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    NSString *orderString = [UICKeyChainStore stringForKey:WPIAPOrderKey];
    NSDictionary *orderDic = [self dictionaryWithJsonString:orderString];
    !_buySuccessBlock? :_buySuccessBlock(orderDic,receiptString);
}

#pragma mark - action - 购买失败
- (void)productPayFailed:(SKPaymentTransaction *)transaction
{
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    _buyFailBlock? :_buyFailBlock(transaction.error);
}

#pragma mark - geter
- (WPIAPHelper *)iapHelper
{
    if (!_iapHelper) {
        _iapHelper = [[WPIAPHelper alloc] init];
    }
    return _iapHelper;
}

#pragma mark - pravite

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
        NSLog(@"json解析失败：%@",err);
        return nil;
    }
    return dic;
}


@end
