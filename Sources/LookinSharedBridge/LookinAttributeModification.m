#import "LookinAttributeModification.h"

@implementation LookinAttributeModification

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.targetOid) forKey:@"targetOid"];
    [coder encodeObject:NSStringFromSelector(self.setterSelector) forKey:@"setterSelector"];
    [coder encodeObject:NSStringFromSelector(self.getterSelector) forKey:@"getterSelector"];
    [coder encodeInteger:self.attrType forKey:@"attrType"];
    [coder encodeObject:self.value forKey:@"value"];
    [coder encodeObject:self.clientReadableVersion forKey:@"clientReadableVersion"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSNumber *oidNum = [coder decodeObjectOfClass:[NSNumber class] forKey:@"targetOid"];
        _targetOid = oidNum ? oidNum.unsignedLongValue : 0;
        NSString *setter = [coder decodeObjectOfClass:[NSString class] forKey:@"setterSelector"];
        _setterSelector = setter ? NSSelectorFromString(setter) : nil;
        NSString *getter = [coder decodeObjectOfClass:[NSString class] forKey:@"getterSelector"];
        _getterSelector = getter ? NSSelectorFromString(getter) : nil;
        _attrType = [coder decodeIntegerForKey:@"attrType"];
        _value = [coder decodeObjectOfClasses:[NSSet setWithArray:@[
            [NSString class], [NSNumber class], [NSValue class], [NSData class]
        ]] forKey:@"value"];
        _clientReadableVersion = [coder decodeObjectOfClass:[NSString class] forKey:@"clientReadableVersion"];
    }
    return self;
}

@end
