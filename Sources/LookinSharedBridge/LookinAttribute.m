#import "LookinAttribute.h"

@implementation LookinAttribute

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.identifier forKey:@"identifier"];
    [coder encodeObject:self.displayTitle forKey:@"displayTitle"];
    [coder encodeInteger:self.attrType forKey:@"attrType"];
    [coder encodeObject:self.value forKey:@"value"];
    [coder encodeObject:self.extraValue forKey:@"extraValue"];
    [coder encodeObject:self.customSetterID forKey:@"customSetterID"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _identifier = [coder decodeObjectOfClass:[NSString class] forKey:@"identifier"];
        _displayTitle = [coder decodeObjectOfClass:[NSString class] forKey:@"displayTitle"];
        _attrType = [coder decodeIntegerForKey:@"attrType"];
        _value = [coder decodeObjectOfClasses:[NSSet setWithArray:@[
            [NSString class], [NSNumber class], [NSValue class],
            [NSArray class], [NSDictionary class], [NSData class]
        ]] forKey:@"value"];
        _extraValue = [coder decodeObjectOfClasses:[NSSet setWithArray:@[
            [NSString class], [NSNumber class], [NSValue class],
            [NSArray class], [NSDictionary class], [NSData class]
        ]] forKey:@"extraValue"];
        _customSetterID = [coder decodeObjectOfClass:[NSString class] forKey:@"customSetterID"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LookinAttribute *copy = [LookinAttribute new];
    copy.identifier = self.identifier;
    copy.displayTitle = self.displayTitle;
    copy.attrType = self.attrType;
    copy.value = self.value;
    copy.extraValue = self.extraValue;
    copy.customSetterID = self.customSetterID;
    return copy;
}

- (BOOL)isUserCustom {
    return self.customSetterID.length > 0;
}

@end
