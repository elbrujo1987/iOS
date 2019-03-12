
#import "CoordinatesUploadOperation.h"
#import "CameraUploadRequestDelegate.h"
#import "MEGAError+MNZCategory.h"
#import "NSFileManager+MNZCategory.h"
@import CoreLocation;

@implementation CoordinatesUploadOperation

- (void)start {
    [super start];
    
    if (self.node.latitude && self.node.longitude) {
        [NSFileManager.defaultManager removeItemIfExistsAtURL:self.attributeURL];
        [self finishOperation];
        return;
    }
    
    CLLocation *location = [NSKeyedUnarchiver unarchiveObjectWithFile:self.attributeURL.path];
    if (location == nil) {
        MEGALogError(@"[Camera Upload] can not unarchive location %@", self);
        [self finishOperation];
        return;
    }
    
    __weak __typeof__(self) weakSelf = self;
    [MEGASdkManager.sharedMEGASdk setUnshareableNodeCoordinates:self.node latitude:@(location.coordinate.latitude) longitude:@(location.coordinate.longitude) delegate:[[CameraUploadRequestDelegate alloc] initWithCompletion:^(MEGARequest * _Nonnull request, MEGAError * _Nonnull error) {
        if (error.type) {
            MEGALogError(@"[Camera Upload] Upload coordinate failed %@ error: %@", weakSelf, error.nativeError);
            if (error.type == MEGAErrorTypeApiEExist) {
                [NSFileManager.defaultManager removeItemIfExistsAtURL:weakSelf.attributeURL];
            }
        } else {
            MEGALogDebug(@"[Camera Upload] Upload coordinate succeeded %@", weakSelf);
            [NSFileManager.defaultManager removeItemIfExistsAtURL:weakSelf.attributeURL];
        }
        
        [weakSelf finishOperation];
    }]];
}

@end
