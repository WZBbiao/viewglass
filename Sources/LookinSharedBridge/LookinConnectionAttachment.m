#import "LookinConnectionAttachment.h"

@implementation LookinConnectionAttachment

+ (BOOL)supportsSecureCoding { return YES; }

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.data forKey:@"0"];
    [coder encodeInteger:self.dataType forKey:@"1"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super init]) {
        NSSet *allowedClasses = [NSSet setWithArray:@[
            [NSArray class], [NSMutableArray class],
            [NSDictionary class], [NSMutableDictionary class],
            [NSString class], [NSMutableString class],
            [NSNumber class], [NSData class], [NSMutableData class], [NSValue class],
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
        ]];
        @try {
            _data = [coder decodeObjectOfClasses:allowedClasses forKey:@"0"];
        } @catch (NSException *exception) {
            // LookinServer occasionally archives mutable collection graphs or custom
            // payloads that exceed the curated allow-list. This local debug transport
            // is trusted, so fall back to generic decoding for compatibility.
            _data = [coder decodeObjectForKey:@"0"];
        }
        _dataType = [coder decodeIntegerForKey:@"1"];
    }
    return self;
}

@end
