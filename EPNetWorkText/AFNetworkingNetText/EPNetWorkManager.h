//
//  EPNetWorkManager.h
//  AFNetworkingNetText
//
//  Created by 邢大象 on 16/3/15.
//  Copyright © 2016年 邢大象. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <SystemConfiguration/SystemConfiguration.h>

typedef NS_ENUM(NSInteger,EPNetWorkStatus) {
    EPNetWorkStatusUnKnown = -1,
    EPNetWorkStatusNotReachable = 0,
    EPNetWorkStatusWWAN = 1,
    EPNetWorkStatusWIFI = 2
};

@interface EPNetWorkManager : NSObject

@property (readonly,nonatomic,assign) EPNetWorkStatus networkStatus;

@property (readonly,nonatomic,assign,getter=isReachable) BOOL reachable;

@property (readonly,nonatomic,assign,getter=isReachableWWAN) BOOL reachableWWAN;

@property (readonly,nonatomic,assign,getter=isReachableWIFI) BOOL reachableWIFI;

+ (instancetype)shareManager;

+ (instancetype)manager;

+ (instancetype)managerForDomain:(NSString *)domain;

+ (instancetype)managerForAddress:(const void *)address;

- (instancetype)initWithReachability:(SCNetworkReachabilityRef)reachability NS_DESIGNATED_INITIALIZER;

- (NSString *)localizedNetworkReachabilityStatusString;

- (void)startMonoriting;

- (void)stopMonoriting;

- (void)setNewWorkStatusChangeBlock:(void (^)(EPNetWorkStatus status))block;

@end
