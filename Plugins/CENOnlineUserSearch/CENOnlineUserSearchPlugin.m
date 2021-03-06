/**
 * @author Serhii Mamontov
 * @version 1.0.0
 * @copyright © 2009-2018 PubNub, Inc.
 */
#import "CENOnlineUserSearchPlugin.h"
#import <CENChatEngine/CEPPlugin+Developer.h>
#import "CENOnlineUserSearchExtension.h"
#import <CENChatEngine/CENChat.h>


#pragma mark Externs

CENOnlineUserSearchConfigurationKeys CENOnlineUserSearchConfiguration = { .propertyName = @"pn", .caseSensitive = @"cs" };


#pragma mark - Interface implementation

@implementation CENOnlineUserSearchPlugin


#pragma mark - Information

+ (NSString *)identifier {
    
    return @"com.chatengine.plugin.online-user-search";
}


#pragma mark - Extension

- (Class)extensionClassFor:(CENObject *)object {
    
    Class extensionClass = nil;
    
    if ([object isKindOfClass:[CENChat class]]) {
        extensionClass = [CENOnlineUserSearchExtension class];
    }
    
    return extensionClass;
}

+ (void)search:(NSString *)criteria inChat:(CENChat *)chat withCompletion:(void(^)(NSArray<CENUser *> *))block {
    
    [chat extensionWithIdentifier:[self identifier] context:^(CENOnlineUserSearchExtension *extension) {
        [extension searchFor:criteria withCompletion:block];
    }];
}


#pragma mark - Handlers

- (void)onCreate {
    
    NSMutableDictionary *configuration = [NSMutableDictionary dictionaryWithDictionary:self.configuration];
    
    if (!configuration[CENOnlineUserSearchConfiguration.propertyName]) {
        configuration[CENOnlineUserSearchConfiguration.propertyName] = @"uuid";
    }
    
    if (!configuration[CENOnlineUserSearchConfiguration.caseSensitive]) {
        configuration[CENOnlineUserSearchConfiguration.caseSensitive] = @NO;
    }
    
    self.configuration = configuration;
}

#pragma mark -


@end
