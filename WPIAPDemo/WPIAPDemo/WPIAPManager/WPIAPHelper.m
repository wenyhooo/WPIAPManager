//
//  WPIAPHelper.m
//  WPIAPDemo
//
//  Created by liwenhao on 2017/8/9.
//  Copyright © 2017年 liwenhaopro. All rights reserved.
//

#import "WPIAPHelper.h"

@interface WPIAPHelper ()
@property (nonatomic, strong) SKProductsRequest *skProductRequest;
@property(nonatomic, copy) void (^successBlock)(NSArray<SKProduct*> *productList);
@property(nonatomic, copy) void (^errorBlock)(NSError *error);
@property(nonatomic, copy) WPIAPPaymentStateBlock paymentStateBlock;
@end
@implementation WPIAPHelper


#pragma mark - public 加载Product信息

- (void)loadProductsWithIdentifiers:(NSSet *)ids
                       successBlock:(void (^)(NSArray<SKProduct*> *productList))successBlock
                         errorBlock:(void (^)(NSError *error))errorBlock
{
    self.successBlock = successBlock;
    self.errorBlock = errorBlock;
    
    self.skProductRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:ids];
    self.skProductRequest.delegate = self;
    [self.skProductRequest start];
}

/**
 购买
 @param product 商品Model
 @param paymentStateBlock 购买状态的返回
 */
- (void)buyProduct:(SKProduct *)product paymentState:(WPIAPPaymentStateBlock) paymentStateBlock
{
    self.paymentStateBlock = paymentStateBlock;
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    SKPayment *payment = [SKPayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

#pragma mark - 购买恢复
/**
 恢复内购
 @param paymentStateBlock  状态回调
 */
- (void)resumeUnfinishedPaymentState:(WPIAPPaymentStateBlock) paymentStateBlock
{
    self.paymentStateBlock = paymentStateBlock;
    //AddObserver之后未完成的支付会继续通知Observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
    if (self.successBlock) {
        self.successBlock(response.products);
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if (self.errorBlock) {
        self.errorBlock(error);
    }
}

#pragma mark - SKPaymentTransactionObserver
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        if (self.paymentStateBlock) {
            self.paymentStateBlock(transaction);
        }
    }
}


@end
