
#import "DiskSpaceDetector.h"
#import "MEGAConstants.h"
#import "CameraUploadManager.h"
#import "NSFileManager+MNZCategory.h"

static const NSUInteger PhotoRetryExtraDiskSpaceInBytes = 5 * 1024 * 1024;
static const NSUInteger VideoRetryExtraDiskSpaceInBytes = 30 * 1024 * 1024;
static const NSTimeInterval RetryTimerInterval = 60;
static const NSTimeInterval RetryTimerTolerance = 6;

@interface DiskSpaceDetector ()

@property (nonatomic) unsigned long long photoRetryDiskFreeSpace;
@property (nonatomic) unsigned long long videoRetryDiskFreeSpace;
@property (strong, nonatomic) NSTimer *photoRetryTimer;
@property (strong, nonatomic) NSTimer *videoRetryTimer;
@property (nonatomic, getter=isDiskFullForPhotos) BOOL diskIsFullForPhotos;
@property (nonatomic, getter=isDiskFullForVideos) BOOL diskIsFullForVideos;

@end

@implementation DiskSpaceDetector

#pragma mark - properties

- (void)setDiskIsFullForPhotos:(BOOL)diskIsFullForPhotos {
    if (_diskIsFullForPhotos != diskIsFullForPhotos) {
        _diskIsFullForPhotos = diskIsFullForPhotos;
        CameraUploadManager.shared.pausePhotoUpload = diskIsFullForPhotos;
        MEGALogDebug(@"[Camera Upload] disk is %@ for photos", diskIsFullForPhotos ? @"full" : @"available");
    }
}

- (void)setDiskIsFullForVideos:(BOOL)diskIsFullForVideos {
    if (_diskIsFullForVideos != diskIsFullForVideos) {
        _diskIsFullForVideos = diskIsFullForVideos;
        CameraUploadManager.shared.pauseVideoUpload = diskIsFullForVideos;
        MEGALogDebug(@"[Camera Upload] disk is %@ for videos", diskIsFullForVideos ? @"full" : @"available");
    }
}

#pragma mark - start and stop detections

- (void)startDetectingPhotoUpload {
    [NSNotificationCenter.defaultCenter removeObserver:self name:MEGACameraUploadPhotoUploadLocalDiskFullNotificationName object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didReceivePhotoUploadDiskFullNotification:) name:MEGACameraUploadPhotoUploadLocalDiskFullNotificationName object:nil];
}

- (void)startDetectingVideoUpload {
    [NSNotificationCenter.defaultCenter removeObserver:self name:MEGACameraUploadVideoUploadLocalDiskFullNotificationName object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(didReceiveVideoUploadDiskFullNotification:) name:MEGACameraUploadVideoUploadLocalDiskFullNotificationName object:nil];
}

- (void)stopDetectingPhotoUpload {
    [NSNotificationCenter.defaultCenter removeObserver:self name:MEGACameraUploadPhotoUploadLocalDiskFullNotificationName object:nil];
    if (self.photoRetryTimer.isValid) {
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [self.photoRetryTimer invalidate];
            self.photoRetryTimer = nil;
        }];
    }
    
    _diskIsFullForPhotos = NO;
}

- (void)stopDetectingVideoUpload {
    [NSNotificationCenter.defaultCenter removeObserver:self name:MEGACameraUploadVideoUploadLocalDiskFullNotificationName object:nil];
    if (self.videoRetryTimer.isValid) {
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [self.videoRetryTimer invalidate];
            self.videoRetryTimer = nil;
        }];
    }
    
    _diskIsFullForVideos = NO;
}

#pragma mark - notifications

- (void)didReceivePhotoUploadDiskFullNotification:(NSNotification *)notification {
    MEGALogDebug(@"[Camera Upload] did receive photo upload disk full notification %@", notification);
    self.diskIsFullForPhotos = YES;
    self.photoRetryDiskFreeSpace = NSFileManager.defaultManager.deviceFreeSize + PhotoRetryExtraDiskSpaceInBytes;
    [NSOperationQueue.mainQueue addOperationWithBlock:^{
        [self setupPhotoUploadRetryTimer];
    }];
}

- (void)didReceiveVideoUploadDiskFullNotification:(NSNotification *)notification {
    MEGALogDebug(@"[Camera Upload] did receive video upload disk full notification %@", notification);
    self.diskIsFullForVideos = YES;
    self.videoRetryDiskFreeSpace = NSFileManager.defaultManager.deviceFreeSize + VideoRetryExtraDiskSpaceInBytes;
    [NSOperationQueue.mainQueue addOperationWithBlock:^{
        [self setupVideoUploadRetryTimer];
    }];
}

#pragma mark - setup timers

- (void)setupPhotoUploadRetryTimer {
    if (self.photoRetryTimer.isValid) {
        [self.photoRetryTimer invalidate];
    }
    
    self.photoRetryTimer = [NSTimer scheduledTimerWithTimeInterval:RetryTimerInterval target:self selector:@selector(firePhotoRetryTimer:) userInfo:nil repeats:YES];
    self.photoRetryTimer.tolerance = RetryTimerTolerance;
}

- (void)firePhotoRetryTimer:(NSTimer *)timer {
    if (NSFileManager.defaultManager.deviceFreeSize > self.photoRetryDiskFreeSpace) {
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [timer invalidate];
        }];
        self.diskIsFullForPhotos = NO;
    }
}

- (void)setupVideoUploadRetryTimer {
    if (self.videoRetryTimer.isValid) {
        [self.videoRetryTimer invalidate];
    }
    
    self.videoRetryTimer = [NSTimer scheduledTimerWithTimeInterval:RetryTimerInterval target:self selector:@selector(fireVideoRetryTimer:) userInfo:nil repeats:YES];
    self.videoRetryTimer.tolerance = RetryTimerTolerance;
}

- (void)fireVideoRetryTimer:(NSTimer *)timer {
    if (NSFileManager.defaultManager.deviceFreeSize > self.videoRetryDiskFreeSpace) {
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            [timer invalidate];
        }];
        
        self.diskIsFullForVideos = NO;
    }
}

@end
