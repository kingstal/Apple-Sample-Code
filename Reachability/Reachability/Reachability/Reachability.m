/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Basic demonstration of how to use the SystemConfiguration Reachablity APIs.
 */

#import <arpa/inet.h>
#import <ifaddrs.h>
#import <netdb.h>
#import <sys/socket.h>
#import <netinet/in.h>

#import <CoreFoundation/CoreFoundation.h>

#import "Reachability.h"

#pragma mark IPv6 Support
//Reachability fully support IPv6.  For full details, see ReadMe.md.


NSString *kReachabilityChangedNotification = @"kNetworkReachabilityChangedNotification";


#pragma mark - Supporting functions

#define kShouldPrintReachabilityFlags 1

// 根据拼接的不同字符我们可以判断不同的网络连接类型，比如 WiFi、2G、3G 等
static void PrintReachabilityFlags(SCNetworkReachabilityFlags flags, const char* comment)
{
#if kShouldPrintReachabilityFlags

    NSLog(@"Reachability Flag Status: %c%c %c%c%c%c%c%c%c %s\n",
          (flags & kSCNetworkReachabilityFlagsIsWWAN)				? 'W' : '-',
          (flags & kSCNetworkReachabilityFlagsReachable)            ? 'R' : '-',

          (flags & kSCNetworkReachabilityFlagsTransientConnection)  ? 't' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionRequired)   ? 'c' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic)  ? 'C' : '-',
          (flags & kSCNetworkReachabilityFlagsInterventionRequired) ? 'i' : '-',
          (flags & kSCNetworkReachabilityFlagsConnectionOnDemand)   ? 'D' : '-',
          (flags & kSCNetworkReachabilityFlagsIsLocalAddress)       ? 'l' : '-',
          (flags & kSCNetworkReachabilityFlagsIsDirect)             ? 'd' : '-',
          comment
          );
#endif
}


static void ReachabilityCallback(SCNetworkReachabilityRef target, SCNetworkReachabilityFlags flags, void* info)
{
#pragma unused (target, flags)
	NSCAssert(info != NULL, @"info was NULL in ReachabilityCallback");
	NSCAssert([(__bridge NSObject*) info isKindOfClass: [Reachability class]], @"info was wrong class in ReachabilityCallback");

    // 因为上述 context 传入的是 self（Reachability 对象），所以这里的 info 为 Reachability 对象类型。
    Reachability* noteObject = (__bridge Reachability *)info;
    // Post a notification to notify the client that the network reachability changed.
    // 发送一个全局通知告诉监听者网络连接状态已发生改变，可通过 noteObject 获取状态。
    [[NSNotificationCenter defaultCenter] postNotificationName: kReachabilityChangedNotification object: noteObject];
}


#pragma mark - Reachability implementation

@implementation Reachability
{
	SCNetworkReachabilityRef _reachabilityRef;
}

+ (instancetype)reachabilityWithHostName:(NSString *)hostName
{
	Reachability* returnValue = NULL;
    // 通过调用 SCNetworkReachabilityCreateWithName C 函数生成一个 SCNetworkReachabilityRef 引用，然后初始化一个 Reachability 对象，并把刚才生成的引用赋给该对象中的 _reachabilityRef 成员变量，以供后面网络状态监听使用
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithName(NULL, [hostName UTF8String]);
	if (reachability != NULL)
	{
		returnValue= [[self alloc] init];
		if (returnValue != NULL)
		{
			returnValue->_reachabilityRef = reachability;
		}
        else {
            CFRelease(reachability);
        }
	}
	return returnValue;
}


+ (instancetype)reachabilityWithAddress:(const struct sockaddr *)hostAddress
{
    // 该方法通过调用 SCNetworkReachabilityCreateWithAddress C 函数生成一个 SCNetworkReachabilityRef 引用，并赋给 Reachability 对象中的 _reachabilityRef 成员变量
	SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(kCFAllocatorDefault, hostAddress);

	Reachability* returnValue = NULL;

	if (reachability != NULL)
	{
		returnValue = [[self alloc] init];
		if (returnValue != NULL)
		{
			returnValue->_reachabilityRef = reachability;
		}
        else {
            CFRelease(reachability);
        }
	}
	return returnValue;
}

// 通过 默认的路由地址 初始化一个 Reachability 对象以进行判断网络连接状态，通常用于 App 没有连接到特定主机的情况 在该方法中先初始化一个默认的 sockaddr_in Socket 地址（这里创建的为零地址，0.0.0.0 地址表示查询本机的网络连接状态），然后调用 reachabilityWithAddress: 方法返回一个 Reachability 对象
+ (instancetype)reachabilityForInternetConnection
{
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
    
    return [self reachabilityWithAddress: (const struct sockaddr *) &zeroAddress];
}

#pragma mark reachabilityForLocalWiFi
//reachabilityForLocalWiFi has been removed from the sample.  See ReadMe.md for more information.
//+ (instancetype)reachabilityForLocalWiFi



#pragma mark - Start and stop notifier

- (BOOL)startNotifier
{
	BOOL returnValue = NO;
    // 构造一个监听网络连接状态的上下文信息
	SCNetworkReachabilityContext context = {0, (__bridge void *)(self), NULL, NULL, NULL};

    // 通过调用 SCNetworkReachabilitySetCallback 函数（并传入 Reachability 对象的 ref，以及根据 SCNetworkReachabilityCallBack 自定义的一个回调函数和上述 context）设置 ref 的网络连接状态变化时对应的回调函数为 ReachabilityCallback；
	if (SCNetworkReachabilitySetCallback(_reachabilityRef, ReachabilityCallback, &context))
	{
        // 通过调用 SCNetworkReachabilityScheduleWithRunLoop 函数设置 Reachability 对象的 ref 在 Current Runloop 中对应的模式（kCFRunLoopDefaultMode）开始监听网络状态；
		if (SCNetworkReachabilityScheduleWithRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode))
		{
			returnValue = YES;
		}
	}

    // 如果监听成功，返回 YES，否则返回 NO。
	return returnValue;
}


- (void)stopNotifier
{
	if (_reachabilityRef != NULL)
	{
        // 通过调用 SCNetworkReachabilityUnscheduleFromRunLoop 函数设置 Reachability 对象的 ref 在 Current Runloop 中对应的模式（kCFRunLoopDefaultMode）取消监听网络状态。
		SCNetworkReachabilityUnscheduleFromRunLoop(_reachabilityRef, CFRunLoopGetCurrent(), kCFRunLoopDefaultMode);
	}
}

// 当要释放一个 Reachability 对象时，我们需要在其 dealloc 方法里取消网络状态监听。另外由于 SCNetworkReachabilityRef 是 Core Foundation 对象，所以这里需要调用 CFRelease() 函数释放 _reachabilityRef。
- (void)dealloc
{
	[self stopNotifier];
	if (_reachabilityRef != NULL)
	{
		CFRelease(_reachabilityRef);
	}
}


#pragma mark - Network Flag Handling

- (NetworkStatus)networkStatusForFlags:(SCNetworkReachabilityFlags)flags
{
	PrintReachabilityFlags(flags, "networkStatusForFlags");
	if ((flags & kSCNetworkReachabilityFlagsReachable) == 0)
	{
		// The target host is not reachable.
		return NotReachable;
	}

    NetworkStatus returnValue = NotReachable;

	if ((flags & kSCNetworkReachabilityFlagsConnectionRequired) == 0)
	{
		/*
         If the target host is reachable and no connection is required then we'll assume (for now) that you're on Wi-Fi...
         */
		returnValue = ReachableViaWiFi;
	}

	if ((((flags & kSCNetworkReachabilityFlagsConnectionOnDemand ) != 0) ||
        (flags & kSCNetworkReachabilityFlagsConnectionOnTraffic) != 0))
	{
        /*
         ... and the connection is on-demand (or on-traffic) if the calling application is using the CFSocketStream or higher APIs...
         */

        if ((flags & kSCNetworkReachabilityFlagsInterventionRequired) == 0)
        {
            /*
             ... and no [user] intervention is needed...
             */
            returnValue = ReachableViaWiFi;
        }
    }

	if ((flags & kSCNetworkReachabilityFlagsIsWWAN) == kSCNetworkReachabilityFlagsIsWWAN)
	{
		/*
         ... but WWAN connections are OK if the calling application is using the CFNetwork APIs.
         */
		returnValue = ReachableViaWWAN;
	}
    
	return returnValue;
}

// 用于判断网络是否需要进一步连接（例如，虽然设备的 WWAN 连接可用，但并没有激活，需要建立一个连接来激活；或者虽然已连接上 WiFi，但该 WiFi 需要进一步 VPN 连接等情况），该方法通过验证 SCNetworkReachabilityFlags 值是否为 kSCNetworkReachabilityFlagsConnectionRequired 判断
- (BOOL)connectionRequired
{
	NSAssert(_reachabilityRef != NULL, @"connectionRequired called with NULL reachabilityRef");
	SCNetworkReachabilityFlags flags;

	if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
	{
		return (flags & kSCNetworkReachabilityFlagsConnectionRequired);
	}

    return NO;
}

- (NetworkStatus)currentReachabilityStatus
{
	NSAssert(_reachabilityRef != NULL, @"currentNetworkStatus called with NULL SCNetworkReachabilityRef");
	NetworkStatus returnValue = NotReachable;
	SCNetworkReachabilityFlags flags;

    // 通过调用 SCNetworkReachabilityGetFlags(...) 函数并传入 _reachabilityRef 引用作为参数，获得一个表示当前网络连接状态的 SCNetworkReachabilityFlags 枚举值
	if (SCNetworkReachabilityGetFlags(_reachabilityRef, &flags))
	{
        // 然后根据枚举值调用 networkStatusForFlags: 方法判断当前网络状态类型并返回
        returnValue = [self networkStatusForFlags:flags];
	}
    
	return returnValue;
}


@end
