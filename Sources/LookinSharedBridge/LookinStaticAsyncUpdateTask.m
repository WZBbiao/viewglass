#import "LookinStaticAsyncUpdateTask.h"

@implementation LookinStaticAsyncUpdateTask

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:@(self.oid) forKey:@"oid"];
    [coder encodeInteger:self.taskType forKey:@"taskType"];
    [coder encodeInteger:self.attrRequest forKey:@"attrRequest"];
    [coder encodeBool:self.needBasisVisualInfo forKey:@"needBasisVisualInfo"];
    [coder encodeBool:self.needSubitems forKey:@"needSubitems"];
    [coder encodeObject:self.clientReadableVersion forKey:@"clientReadableVersion"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSNumber *oidNum = [coder decodeObjectOfClass:[NSNumber class] forKey:@"oid"];
        _oid = oidNum ? oidNum.unsignedLongValue : 0;
        _taskType = [coder decodeIntegerForKey:@"taskType"];
        _attrRequest = [coder decodeIntegerForKey:@"attrRequest"];
        _needBasisVisualInfo = [coder decodeBoolForKey:@"needBasisVisualInfo"];
        _needSubitems = [coder decodeBoolForKey:@"needSubitems"];
        _clientReadableVersion = [coder decodeObjectOfClass:[NSString class] forKey:@"clientReadableVersion"];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (![object isKindOfClass:[LookinStaticAsyncUpdateTask class]]) return NO;
    LookinStaticAsyncUpdateTask *other = object;
    return self.oid == other.oid && self.taskType == other.taskType;
}

- (NSUInteger)hash {
    return self.oid ^ self.taskType;
}

@end

@implementation LookinStaticAsyncUpdateTasksPackage

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.tasks forKey:@"tasks"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSSet *classes = [NSSet setWithArray:@[[NSArray class], [LookinStaticAsyncUpdateTask class]]];
        _tasks = [coder decodeObjectOfClasses:classes forKey:@"tasks"];
    }
    return self;
}

@end
