//
//  WPIAPHelper.h
//  WPIAPDemo
//
//  Created by liwenhao on 2017/8/9.
//  Copyright © 2017年 liwenhaopro. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

typedef void(^WPIAPPaymentStateBlock)(SKPaymentTransaction *transaction);

@interface WPIAPHelper : NSObject<SKProductsRequestDelegate, SKPaymentTransactionObserver>

/**
 去苹果请求内购
 @param ids 内购id
 @param successBlock 成功
 @param errorBlock 失败
 */

- (void)loadProductsWithIdentifiers:(NSSet *)ids
                       successBlock:(void (^)(NSArray<SKProduct*> *productList))successBlock
                         errorBlock:(void (^)(NSError *error))errorBlock;
/**
 恢复内购
 @param paymentStateBlock  状态回调
 */
- (void)resumeUnfinishedPaymentState:(WPIAPPaymentStateBlock) paymentStateBlock;

/**
 购买
 @param product 商品Model
 @param paymentStateBlock 购买状态的返回
 */
- (void)buyProduct:(SKProduct *)product paymentState:(WPIAPPaymentStateBlock) paymentStateBlock;
@end
