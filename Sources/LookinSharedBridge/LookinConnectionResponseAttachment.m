#import "LookinConnectionResponseAttachment.h"

@implementation LookinConnectionResponseAttachment

+ (BOOL)supportsSecureCoding { return YES; }

+ (instancetype)attachmentWithError:(NSError *)error {
    LookinConnectionResponseAttachment *att = [LookinConnectionResponseAttachment new];
    att.error = error;
    return att;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [super encodeWithCoder:coder];
    [coder encodeInt:self.lookinServerVersion forKey:@"lookinServerVersion"];
    [coder encodeObject:self.error forKey:@"error"];
    [coder encodeObject:@(self.dataTotalCount) forKey:@"dataTotalCount"];
    [coder encodeObject:@(self.currentDataCount) forKey:@"currentDataCount"];
    [coder encodeBool:self.appIsInBackground forKey:@"appIsInBackground"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    if (self = [super initWithCoder:coder]) {
        _lookinServerVersion = [coder decodeIntForKey:@"lookinServerVersion"];
        _error = [coder decodeObjectOfClass:[NSError class] forKey:@"error"];
        NSNumber *total = [coder decodeObjectOfClass:[NSNumber class] forKey:@"dataTotalCount"];
        _dataTotalCount = total ? total.unsignedIntegerValue : 0;
        NSNumber *current = [coder decodeObjectOfClass:[NSNumber class] forKey:@"currentDataCount"];
        _currentDataCount = current ? current.unsignedIntegerValue : 0;
        _appIsInBackground = [coder decodeBoolForKey:@"appIsInBackground"];
    }
    return self;
}

@end
