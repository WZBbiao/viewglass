#import "LookinConnectionAttachment.h"

@implementation LookinConnectionAttachment

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.data forKey:@"0"];
    [coder encodeInteger:self.dataType forKey:@"1"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        _data = [coder decodeObjectOfClasses:[NSSet setWithArray:@[
            [NSArray class], [NSDictionary class], [NSString class],
            [NSNumber class], [NSData class], [NSValue class],
            [NSError class],
            NSClassFromString(@"LookinAppInfo") ?: [NSObject class],
            NSClassFromString(@"LookinHierarchyInfo") ?: [NSObject class],
            NSClassFromString(@"LookinDisplayItem") ?: [NSObject class],
            NSClassFromString(@"LookinDisplayItemDetail") ?: [NSObject class],
            NSClassFromString(@"LookinObject") ?: [NSObject class],
            NSClassFromString(@"LookinAttributesGroup") ?: [NSObject class],
            NSClassFromString(@"LookinAttributesSection") ?: [NSObject class],
            NSClassFromString(@"LookinAttribute") ?: [NSObject class],
            NSClassFromString(@"LookinEventHandler") ?: [NSObject class],
            NSClassFromString(@"LookinIvarTrace") ?: [NSObject class],
            NSClassFromString(@"LookinStaticAsyncUpdateTask") ?: [NSObject class],
            NSClassFromString(@"LookinStaticAsyncUpdateTasksPackage") ?: [NSObject class],
            NSClassFromString(@"LookinHierarchyFile") ?: [NSObject class],
        ]] forKey:@"0"];
        _dataType = [coder decodeIntegerForKey:@"1"];
    }
    return self;
}

@end
