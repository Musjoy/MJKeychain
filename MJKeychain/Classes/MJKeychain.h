//
//  MJKeychain.h
//  Pods
//
//  Created by 黄磊 on 2017/6/1.
//  Copyright © 2017年 Musjoy. All rights reserved.
//

#import <Foundation/Foundation.h>
// 后续添加统一KeychainItem
//#import "MJKeychainItem.h"

/// 默认服务，这里再屌用defaultKeychain和defaultSharedKeychain时使用
#ifndef kKeychainDefaultService
#define kKeychainDefaultService         [[[NSBundle mainBundle] bundleIdentifier] stringByAppendingString:@".DefaultService"]
#endif

#ifndef kKeychainSharedAccessGroup
#define kKeychainSharedAccessGroup      @"KeychainGroups"
#endif

@interface MJKeychain : NSObject

/// 读取默认keychain，即accessGroup=nil，这个时候又可能与defaultSharedKeychain是同一个group
+ (id)defaultKeychain;

/// 读取可共享的keychain，这里必须添加Keychain Sharing Capability，而且必须以kKeychainSharedAccessGroup结尾，这里保存的数据可与其它app共享
+ (id)defaultSharedKeychain;

/// 共享的AccessGroup，可能返回为nil
+ (NSString *)sharedAccessGroup;

/// 这里的identifier会被设置到kSecAttrService
- (id)initWithIdentifier:(NSString *)identifier accessGroup:(NSString *)accessGroup;

/// 设置keychain中对应key的值，这里key代表kSecAttrAccount，Object代表kSecAttrGeneric，暂时不使用kSecValueData
- (void)setObject:(id)object forKey:(NSString *)key;
/// 返回keychain中保存的object，这里取得是kSecAttrGeneric中的值
- (id)objectForKey:(NSString *)key;
/// 移除keychain中保存的该数据，key代表kSecAttrAccount
- (BOOL)removeObjectForKey:(NSString *)key;

// 后续开发
//- (void)addItem:(MJKeychainItem *)item;
//
//- (void)deleteItemForKey:(NSString *)key;
//
//- (void)updateItem:(MJKeychainItem *)item;
//
//+ (NSArray *)itemList;

@end
