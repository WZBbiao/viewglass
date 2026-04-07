#import "LookinEventHandler.h"

@implementation LookinEventHandler

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.handlerOid) forKey:@"handlerOid"];
    [coder encodeObject:self.handlerClassName forKey:@"handlerClassName"];
    [coder encodeBool:self.recognizerIsEnabled forKey:@"recognizerIsEnabled"];
    [coder encodeObject:self.eventName forKey:@"eventName"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSNumber *oidNum = [coder decodeObjectOfClass:[NSNumber class] forKey:@"handlerOid"];
        _handlerOid = oidNum ? oidNum.unsignedLongValue : 0;
        _handlerClassName = [coder decodeObjectOfClass:[NSString class] forKey:@"handlerClassName"];
        _recognizerIsEnabled = [coder decodeBoolForKey:@"recognizerIsEnabled"];
        _eventName = [coder decodeObjectOfClass:[NSString class] forKey:@"eventName"];
    }
    return self;
}

@end
