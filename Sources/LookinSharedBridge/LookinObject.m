#import "LookinObject.h"
#import "LookinIvarTrace.h"

@implementation LookinObject

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.oid) forKey:@"oid"];
    [coder encodeObject:self.memoryAddress forKey:@"memoryAddress"];
    [coder encodeObject:self.classChainList forKey:@"classChainList"];
    [coder encodeObject:self.specialTrace forKey:@"specialTrace"];
    [coder encodeObject:self.ivarTraces forKey:@"ivarTraces"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSNumber *oidNum = [coder decodeObjectOfClass:[NSNumber class] forKey:@"oid"];
        _oid = oidNum ? oidNum.unsignedLongValue : 0;
        _memoryAddress = [coder decodeObjectOfClass:[NSString class] forKey:@"memoryAddress"];
        _classChainList = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [NSString class]]] forKey:@"classChainList"];
        _specialTrace = [coder decodeObjectOfClass:[NSString class] forKey:@"specialTrace"];
        _ivarTraces = [coder decodeObjectOfClasses:[NSSet setWithArray:@[[NSArray class], [LookinIvarTrace class]]] forKey:@"ivarTraces"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LookinObject *copy = [LookinObject new];
    copy.oid = self.oid;
    copy.memoryAddress = self.memoryAddress;
    copy.classChainList = self.classChainList;
    copy.specialTrace = self.specialTrace;
    copy.ivarTraces = self.ivarTraces;
    return copy;
}

- (NSString *)rawClassName {
    return self.classChainList.firstObject;
}

@end
