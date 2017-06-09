//
//  MJKeychain.m
//  Pods
//
//  Created by 黄磊 on 2017/6/1.
//  Copyright © 2017年 Musjoy. All rights reserved.
//

#import "MJKeychain.h"

static NSString *s_sharedAccessGroup = nil;


@interface MJKeychain ()

@property (nonatomic, strong) NSString *identifier;
@property (nonatomic, strong) NSString *accessGroup;
@property (nonatomic, strong) NSMutableDictionary *dicItems;
@property (nonatomic, strong) NSMutableDictionary *dicQuery;

@end


@implementation MJKeychain


#pragma mark - Class Fun

+ (id)defaultKeychain
{
    static MJKeychain *s_defaultKeychain = nil;
    static dispatch_once_t once_patch;
    dispatch_once(&once_patch, ^() {
        s_defaultKeychain = [[MJKeychain alloc] initWithIdentifier:kKeychainDefaultService accessGroup:nil];
    });
    return s_defaultKeychain;
}

+ (id)defaultSharedKeychain
{
    static MJKeychain *s_defaultSharedKeychain = nil;
    static dispatch_once_t once_patch;
    dispatch_once(&once_patch, ^() {
        s_defaultSharedKeychain = [[MJKeychain alloc] initWithIdentifier:kKeychainDefaultService accessGroup:[MJKeychain sharedAccessGroup]];
    });
    return s_defaultSharedKeychain;
}

+ (NSString *)sharedAccessGroup
{
    if (s_sharedAccessGroup) {
        return s_sharedAccessGroup;
    }
    
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (id)kSecClassGenericPassword, kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           (id)kSecMatchLimitAll, kSecMatchLimit,
                           nil];
    CFArrayRef result = NULL;
    NSArray *arrGroups = nil;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        CFDictionaryRef refResult = NULL;
        query = [NSDictionary dictionaryWithObjectsAndKeys:
                 (id)kSecClassGenericPassword, kSecClass,
                 @"bundleSeedID", kSecAttrAccount,
                 @"", kSecAttrService,
                 (id)kCFBooleanTrue, kSecReturnAttributes,
                 nil];
        status = SecItemAdd((CFDictionaryRef)query, (CFTypeRef *)&refResult);
        NSDictionary *aDic = (__bridge NSDictionary *)refResult;
        if (aDic) {
            arrGroups = @[aDic];
        }
    } else {
        arrGroups = (__bridge NSArray *)result;
    }
    if (status != errSecSuccess) {
        return nil;
    }
    
    for (NSDictionary *aDic in arrGroups) {
        NSString *aAccessGroup = [aDic objectForKey:(id)kSecAttrAccessGroup];
        if ([aAccessGroup hasSuffix:kKeychainSharedAccessGroup]) {
            s_sharedAccessGroup = aAccessGroup;
            break;
        }
    }
    
    if (s_sharedAccessGroup == nil) {
        LogError(@"\n\n\tAccess group with suffix { %@ } is not found! You need to enable 'Keychain Sharing' in target capabilities, And add an Access group with suffix '%@'\n\n.", kKeychainSharedAccessGroup, kKeychainSharedAccessGroup);
    }
    return s_sharedAccessGroup;
}


#pragma mark - Init

- (id)initWithIdentifier:(NSString *)identifier accessGroup:(NSString *)accessGroup
{
    self = [super init];
    if (self) {
        if (identifier.length == 0) {
            LogError(@"Cann't operate without identifier");
            return nil;
        }
        _identifier = identifier;
        _accessGroup = accessGroup;
        _dicQuery = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                     (id)kSecClassGenericPassword, kSecClass,
                     kCFBooleanTrue, kSecReturnAttributes,
                     _identifier, kSecAttrService,
                     _accessGroup, kSecAttrAccessGroup, nil];
        _dicItems = [[NSMutableDictionary alloc] init];
    }
    return self;
}


- (void)setObject:(id)object forKey:(NSString *)key
{
    NSMutableDictionary *dicQuery = [_dicQuery mutableCopy];
    [dicQuery setObject:key forKey:(id)kSecAttrAccount];
    
    CFDictionaryRef cfResult = NULL;
    OSStatus result;
    
    if (SecItemCopyMatching((CFDictionaryRef)dicQuery, (CFTypeRef *)&cfResult) == noErr) {
        // 找到对应数据，对该数据进行更新
        NSMutableDictionary *attributes = [(__bridge NSDictionary*)cfResult mutableCopy];
        NSString *oldValue = [attributes objectForKey:(id)kSecAttrGeneric];
        if ([oldValue isEqualToString:object]) {
            return;
        }
        
        if (object == nil) {
            [attributes removeObjectForKey:(id)kSecAttrGeneric];
            object = [NSNull null];
        } else {
            // 保存到内存
            [attributes setObject:object forKey:(id)kSecAttrGeneric];
        }
        NSDictionary *dicUpdate = [NSDictionary dictionaryWithObjectsAndKeys:object, kSecAttrGeneric, nil];
        
        result = SecItemUpdate((CFDictionaryRef)dicQuery, (CFDictionaryRef)dicUpdate);
        NSAssert( result == noErr, @"Couldn't update the Keychain Item." );
        
        [_dicItems setObject:attributes forKey:key];
    } else {
        if (object == nil) {
            return;
        }
        [dicQuery setObject:object forKey:(id)kSecAttrGeneric];
        result = SecItemAdd((CFDictionaryRef)dicQuery, (CFTypeRef *)&cfResult);
        NSAssert( result == noErr, @"Couldn't add the Keychain Item." );
        NSMutableDictionary *attributes = [(__bridge NSDictionary*)cfResult mutableCopy];
        [_dicItems setObject:attributes forKey:key];
    }
}

- (id)objectForKey:(NSString *)key
{
    NSDictionary *attributes = [_dicItems objectForKey:key];
    if (attributes) {
        return [attributes objectForKey:(id)kSecAttrGeneric];
    }
    
    NSMutableDictionary *dicQuery = [_dicQuery mutableCopy];
    [dicQuery setObject:key forKey:(id)kSecAttrAccount];
    
    CFDictionaryRef cfResult = NULL;
    OSStatus result = SecItemCopyMatching((CFDictionaryRef)dicQuery, (CFTypeRef *)&cfResult);
    
    if (result == noErr) {
        // 找到对应数据，对该数据进行更新
        NSMutableDictionary *attributes = [(__bridge NSDictionary*)cfResult mutableCopy];
        [_dicItems setObject:attributes forKey:key];
        return [attributes objectForKey:(id)kSecAttrGeneric];
    } else {
        return nil;
    }
}

- (BOOL)removeObjectForKey:(NSString *)key
{
    NSMutableDictionary *dicQuery = [_dicQuery mutableCopy];
    [dicQuery setObject:key forKey:(id)kSecAttrAccount];
    
    OSStatus result = SecItemDelete((CFDictionaryRef)dicQuery);
    return (result==noErr)?YES:NO;
}

@end
