#import "LookinIvarTrace.h"

@implementation LookinIvarTrace

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.hostClassName forKey:@"hostClassName"];
    [coder encodeObject:self.ivarName forKey:@"ivarName"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _hostClassName = [coder decodeObjectOfClass:[NSString class] forKey:@"hostClassName"];
        _ivarName = [coder decodeObjectOfClass:[NSString class] forKey:@"ivarName"];
    }
    return self;
}

@end
