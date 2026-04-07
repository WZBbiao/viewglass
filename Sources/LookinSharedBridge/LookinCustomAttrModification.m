#import "LookinCustomAttrModification.h"

@implementation LookinCustomAttrModification

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeInteger:self.attrType forKey:@"attrType"];
    [coder encodeObject:self.customSetterID forKey:@"customSetterID"];
    [coder encodeObject:self.value forKey:@"value"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _attrType = [coder decodeIntegerForKey:@"attrType"];
        _customSetterID = [coder decodeObjectOfClass:[NSString class] forKey:@"customSetterID"];
        _value = [coder decodeObjectOfClasses:[NSSet setWithArray:@[
            [NSString class], [NSNumber class], [NSValue class], [NSData class]
        ]] forKey:@"value"];
    }
    return self;
}

@end
