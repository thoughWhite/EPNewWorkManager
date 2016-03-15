//
//  EPNetWorkManager.m
//  AFNetworkingNetText
//
//  Created by 邢大象 on 16/3/15.
//  Copyright © 2016年 邢大象. All rights reserved.
//

#import "EPNetWorkManager.h"


#import <netinet/in.h>
#import <netinet6/in6.h>
#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>


NSString * const EPNetWorkingDidChangeNotification = @"thoughWhitechange";
NSString * const EPNetWorkingNotificationStatusItem = @"thoughWhiteNOtificationStatusItem";

typedef void (^EPNetWorkStatusBlock)(EPNetWorkStatus status);

NSString *EPStringFromNetWorkStatus(EPNetWorkStatus status) {
    switch (status) {
        case EPNetWorkStatusNotReachable:
            return NSLocalizedStringFromTable(@"Not Reachable", @"EPNetWork", nil);
        case EPNetWorkStatusWWAN:
            return NSLocalizedStringFromTable(@"Reachable is WWAN", @"EPNetWork", nil);
        case EPNetWorkStatusWIFI:
            return NSLocalizedStringFromTable(@"Reachable is WIFI", @"EPNetWork", nil);
        case EPNetWorkStatusUnKnown:
        default:
            return NSLocalizedStringFromTable(@"UnKnown", @"EPNetWork", nil);
    }
}

static EPNetWorkStatus EPNetWorkStatusForFlags(SCNetworkReachabilityFlags flags) {
    BOOL isReachable = ((flags & kSCNetworkReachabilityFlagsReachable) != 0);
    BOOL needConnection = ((flags & kSCNetworkReachabilityFlagsConnectionRequired) != 0);
    BOOL canConnectionAutomatically = ((flags & kSCNetworkReachabilityFlagsConnectionOnDemand) != 0) || ((flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0);
    BOOL canConnectionWithoutUserInteraction = (canConnectionAutomatically && (flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0);
    BOOL isNetWorkReachable = (isReachable &&(!needConnection || canConnectionWithoutUserInteraction));
    
    EPNetWorkStatus status = EPNetWorkStatusUnKnown;
    if (isNetWorkReachable == NO) {
        status = EPNetWorkStatusNotReachable;
    }
#if	TARGET_OS_IPHONE
    else if ((flags & kSCNetworkReachabilityFlagsIsWWAN) != 0) {
        status = EPNetWorkStatusWWAN;
    }
#endif
    else {
        status = EPNetWorkStatusWIFI;
    }
    return status;
    
}

static void EPPostStatusChange(SCNetworkConnectionFlags flags, EPNetWorkStatusBlock block) {
    EPNetWorkStatus status = EPNetWorkStatusForFlags(flags);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (block) {
            block(status);
        }
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        NSDictionary *userInfo = @{EPNetWorkingNotificationStatusItem:@(status)};
        [notificationCenter postNotificationName:EPNetWorkingDidChangeNotification object:nil userInfo:userInfo];
    });
}

static void EPNetWorkCallBack(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags,void *info) {
    EPPostStatusChange(flags, (__bridge EPNetWorkStatusBlock)(info));
}

static const void *EPNetWorkRetainCallback(const void *info) {
    return Block_copy(info);
}

static void EPNetWorkReleaseCallback(const void *info) {
    if (info) {
        Block_release(info);
    }
}

@interface EPNetWorkManager ()
@property (readonly, nonatomic, assign) SCNetworkReachabilityRef networkReachability;
@property (readwrite, nonatomic, assign) EPNetWorkStatus networkStatus;
@property (readwrite, nonatomic, copy) EPNetWorkStatusBlock networkStatusBlock;
@end


@implementation EPNetWorkManager

+ (instancetype)shareManager {
    static EPNetWorkManager *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self manager];
    });
    
    return manager;
}

+ (instancetype)managerForDomain:(NSString *)domain {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(kCFAllocatorDefault, [domain UTF8String]);
    
    EPNetWorkManager *manager = [[self alloc]initWithReachability:reachability];
    
    CFRelease(reachability);
    
    return manager;
}

+ (instancetype)managerForAddress:(const void *)address {
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, (const struct sockaddr *)address);
    EPNetWorkManager *manager = [[self alloc]initWithReachability:reachability];
    
    CFRelease(reachability);
    
    return manager;
}

+ (instancetype)manager {
#if (defined(__IPHONE_OS_VERSION_MIN_REQUIRED) && __IPHONE_OS_VERSION_MIN_REQUIRED >= 90000) || (defined(__MAC_OS_X_VERSION_MIN_REQUIRED) && __MAC_OS_X_VERSION_MIN_REQUIRED >= 101100)
    struct sockaddr_in6 address;
    bzero(&address, sizeof(address));
    address.sin6_len = sizeof(address);
    address.sin6_family = AF_INET6;
#else 
    struct sockaddr_in address;
    bzero(&address, sizeof(address));
    address.sin6_len = sizeof(address);
    address.sin6_family = AF_INET;
#endif
    return [self managerForAddress:&address];
    
}

- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability {
    self = [super init];
    if (!self) {
        return nil;
    }
    
    _networkReachability = CFRetain(reachability);
    self.networkStatus = EPNetWorkStatusUnKnown;
    
    return self;
}

- (instancetype)init NS_UNAVAILABLE {
    return nil;
}

- (void)dealloc {
    [self stopMonoriting];
    
    if (_networkReachability != NULL) {
        CFRelease(_networkReachability);
    }
}

#pragma mark - 

- (BOOL)isReachable {
    return [self isReachableWWAN] || [self isReachableWIFI];
}

- (BOOL)isReachableWWAN {
    return self.networkStatus = EPNetWorkStatusWWAN;
}

- (BOOL)isReachableWIFI {
    return self.networkStatus == EPNetWorkStatusWIFI;
}


#pragma mark -

- (void)startMonoriting {
    [self stopMonoriting];
    
    if (!self.networkReachability) {
        return;
    }
    
    __weak __typeof(self)weakSelf = self;
    
    EPNetWorkStatusBlock callBack = ^(EPNetWorkStatus status) {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf.networkStatus = status;
        if (strongSelf.networkStatusBlock) {
            strongSelf.networkStatusBlock(status);
        }
    };
    
    
    SCNetworkReachabilityContext context = {0,(__bridge void * _Nullable)(callBack),EPNetWorkRetainCallback,EPNetWorkReleaseCallback,NULL};
    
    SCNetworkReachabilitySetCallback(self.networkReachability, EPNetWorkCallBack, &context);
    SCNetworkReachabilityScheduleWithRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        SCNetworkReachabilityFlags flags;
        if (SCNetworkReachabilityGetFlags(self.networkReachability, &flags)) {
            EPPostStatusChange(flags, callBack);
        }
    });
}

- (void)stopMonoriting {
    if (!self.networkReachability) {
        return;
    }
    
    SCNetworkReachabilityUnscheduleFromRunLoop(self.networkReachability, CFRunLoopGetMain(), kCFRunLoopCommonModes);
    
}

#pragma mark -

- (NSString *)localizedNetworkReachabilityStatusString {
    return EPStringFromNetWorkStatus(self.networkStatus);
}

#pragma mark -

- (void)setNewWorkStatusChangeBlock:(void (^)(EPNetWorkStatus status))block {
    self.networkStatusBlock = block;
}

#pragma mark NSKeyValueObserving

+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    if ([key isEqualToString:@"reachable"] || [key isEqualToString:@"reachableWWAN"] || [key isEqualToString:@"reachableWIFI"]) {
        return [NSSet setWithObject:@"networkStatus"];
    }
    
    return [super keyPathsForValuesAffectingValueForKey:key];
}


@end
