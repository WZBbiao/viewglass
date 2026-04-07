#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "LookinDefines.h"

NS_ASSUME_NONNULL_BEGIN

@interface LookinStaticAsyncUpdateTask : NSObject <NSSecureCoding>

@property(nonatomic, assign) unsigned long oid;
@property(nonatomic, assign) LookinStaticAsyncUpdateTaskType taskType;
@property(nonatomic, assign) LookinDetailUpdateTaskAttrRequest attrRequest;
@property(nonatomic, assign) BOOL needBasisVisualInfo;
@property(nonatomic, assign) BOOL needSubitems;
@property(nonatomic, copy, nullable) NSString *clientReadableVersion;
@property(nonatomic, assign) CGSize frameSize;

@end

@interface LookinStaticAsyncUpdateTasksPackage : NSObject <NSSecureCoding>

@property(nonatomic, copy, nullable) NSArray<LookinStaticAsyncUpdateTask *> *tasks;

@end

NS_ASSUME_NONNULL_END
