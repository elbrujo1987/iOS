
#import <Foundation/Foundation.h>
@import Photos;

NS_ASSUME_NONNULL_BEGIN

@interface CameraUploadManager : NSObject

+ (instancetype)shared;

- (void)startUploading;

- (void)uploadNextForAsset:(PHAsset *)asset;

@end

NS_ASSUME_NONNULL_END
