//
//  MJKeychain.m
//  Pods
//
//  Created by 黄磊 on 2017/6/1.
//  Copyright © 2017年 Musjoy. All rights reserved.
//

#import "MJKeychain.h"

static NSString *s_defaultAccessGroup = nil;
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
        s_defaultKeychain = [[MJKeychain alloc] initWithIdentifier:kKeychainDefaultService accessGroup:[self defaultAccessGroup]];
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

+ (NSString *)defaultAccessGroup
{
    if (s_defaultAccessGroup) {
        return s_defaultAccessGroup;
    }
    
    NSDictionary *query = [NSDictionary dictionaryWithObjectsAndKeys:
                           (id)kSecClassGenericPassword, kSecClass,
                           @"bundleSeedID", kSecAttrAccount,
                           @"", kSecAttrService,
                           (id)kCFBooleanTrue, kSecReturnAttributes,
                           nil];
    CFDictionaryRef result = NULL;
    OSStatus status = SecItemCopyMatching((CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecItemNotFound) {
        status = SecItemAdd((CFDictionaryRef)query, (CFTypeRef *)&result);
        if (status != errSecSuccess) {
            return nil;
        }
    }
    NSString *aAccessGroup = [(__bridge NSDictionary *)result objectForKey:(id)kSecAttrAccessGroup];
    NSArray *components = [aAccessGroup componentsSeparatedByString:@"."];
    NSString *bundleSeedId = [[components objectEnumerator] nextObject];
    if (result) {
        CFRelease(result);
    }
    
    s_defaultAccessGroup = [bundleSeedId stringByAppendingFormat:@".%@", [[NSBundle mainBundle] bundleIdentifier]];
    
    return s_defaultAccessGroup;
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
        if (status != errSecSuccess) {
            return nil;
        }
        NSDictionary *aDic = (__bridge NSDictionary *)refResult;
        if (refResult) {
            CFRelease(refResult);
        }
        if (aDic) {
            arrGroups = @[aDic];
        }
    } else {
        arrGroups = (__bridge NSArray *)result;
        if (result) {
            CFRelease(result);
        }
    }
    
    for (NSDictionary *aDic in arrGroups) {
        NSString *aAccessGroup = [aDic objectForKey:(id)kSecAttrAccessGroup];
        if ([aAccessGroup hasSuffix:kKeychainSharedAccessGroup]) {
            s_sharedAccessGroup = aAccessGroup;
            break;
        }
    }
    
    if (s_sharedAccessGroup == nil) {
        // 这里可能是开发刚修改正确，所有需要尝试再创建一个
        CFDictionaryRef refResult = NULL;
        query = [NSDictionary dictionaryWithObjectsAndKeys:
                 (id)kSecClassGenericPassword, kSecClass,
                 @"bundleSeedID", kSecAttrAccount,
                 @"", kSecAttrService,
                 (id)kCFBooleanTrue, kSecReturnAttributes,
                 nil];
        status = SecItemAdd((CFDictionaryRef)query, (CFTypeRef *)&refResult);
        if (status == errSecSuccess) {
            NSString *aAccessGroup = [(__bridge NSDictionary *)refResult objectForKey:(id)kSecAttrAccessGroup];
            if ([aAccessGroup hasSuffix:kKeychainSharedAccessGroup]) {
                s_sharedAccessGroup = aAccessGroup;
                return s_sharedAccessGroup;
            }
            if (refResult) {
                CFRelease(refResult);
            }
        }
        
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
        // kSecClassGenericPassword表:genp 这个表的主键是kSecAttrAccount 和kSecAttrService
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
        if (object == nil || [object isKindOfClass:[NSNull class]]) {
            result = SecItemDelete((CFDictionaryRef)dicQuery);
            NSAssert( result == noErr, @"Couldn't delete the Keychain Item." );
            return;
        }
        
        NSString *oldValue = [attributes objectForKey:(id)kSecAttrGeneric];
        if ([oldValue isMemberOfClass:[object class]]) {
            if ([oldValue isKindOfClass:[NSString class]] && [oldValue isEqualToString:object]) {
                return;
            } else if ([oldValue isKindOfClass:[NSNumber class]] && [(NSNumber *)oldValue isEqualToNumber:object]) {
                return;
            }
        }
        
        
        [attributes setObject:object forKey:(id)kSecAttrGeneric];

        [dicQuery removeObjectForKey:(id)kSecReturnAttributes];
        
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
        if (attributes) {
            [_dicItems setObject:attributes forKey:key];
        }
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
        if (attributes) {
            [_dicItems setObject:attributes forKey:key];
        }
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
