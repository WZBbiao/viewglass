#import <Foundation/Foundation.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinEventHandler : NSObject <NSSecureCoding>

@property(nonatomic, assign) unsigned long handlerOid;
@property(nonatomic, copy, nullable) NSString *handlerClassName;
@property(nonatomic, assign) BOOL recognizerIsEnabled;
@property(nonatomic, copy, nullable) NSString *eventName;

@end

NS_ASSUME_NONNULL_END
