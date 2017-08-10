//
//  WPIAPManager.h
//  WPIAPDemo
//
//  Created by liwenhao on 2017/8/9.
//  Copyright © 2017年 liwenhaopro. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

typedef void (^WPbuyIapSuccessBlock)(NSDictionary *orderDic,NSString *receiptString);

#define WPIAPManagerM [WPIAPManager sharedManager]

@interface WPIAPManager : NSObject

/**
 生成单例对象
 如果调用单例 会缓存重复点击的iap  product, searchAppleProduct
 */
+ (WPIAPManager *)sharedManager;

/**
 检查是否有历史充值问题 (包括本地和apple都有可能存在的遗留问题)
 @param resumBlock 如果有订单恢复  会回调
 */
- (void)appLaunchCheckresumeAppleServiceIAP:(WPbuyIapSuccessBlock)resumBlock;

/**
 iap购买
 @param productIdfier 商品ID
 @param orderDic  携带的订单信息 会随着购买凭证存入KeyChain,
 @param buySuccessBlock 购买成功后 需要向自己服务端验证 成功后要手动调用   cleanAppleOrderInfo
 @param buyFailBlock 购买失败
 */
- (void)buyAppleWithSKProductIdfier:(NSString *)productIdfier withOrderDic:(NSDictionary *)orderDic buySuccessBlock:(WPbuyIapSuccessBlock)buySuccessBlock buyFailBlock:(void (^)(NSError *error))buyFailBlock;

/**
 订单验证成功后或者认定丢弃 调用
 */
+ (void)cleanAppleOrderInfo;

/**
 去苹果服务器查询商品
 @param productIdfier 商品ID
 @param searchSuccessBlock 查询成功
 @param failBlock 查询失败
 */
- (void)searchAppleProduct:(NSString *)productIdfier searchSuccessBlock:(void (^)(SKProduct *skRroduct))searchSuccessBlock failBlock:(void (^)(NSError *error))failBlock;

/**
 去苹果服务器查询商品
 @param productIdfierList 商品ID list
 @param searchSuccessBlock 查询成功
 @param failBlock 查询失败
 */
- (void)searchAppleProductList:(NSSet *)productIdfierList searchSuccessBlock:(void (^)(NSArray<SKProduct *> *skRroduct))searchSuccessBlock failBlock:(void (^)(NSError *error))failBlock;

/**
 iap购买
 @param skProduct SK商品对象
 @param orderDic 携带的订单信息 会随着购买凭证存入KeyChain
 @param buySuccessBlock 购买成功
 @param buyFailBlock 购买失败
 */
- (void)buyAppleWithSKProduct:(SKProduct *)skProduct withOrderDic:(NSDictionary *)orderDic buySuccessBlock:(WPbuyIapSuccessBlock )buySuccessBlock buyFailBlock:(void (^)(NSError *error))buyFailBlock;

@end
