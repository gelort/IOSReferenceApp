//
//  Client.m
//  Kaltura
//
//  Created by Pavel on 28.02.12.
//  Copyright (c) 2012 Kaltura. All rights reserved.
//

#import "Client.h"
#import "WViPhoneAPI.h"

static NSArray *sBitRates;

@implementation Client

@synthesize client;
@synthesize categories;
@synthesize media;
@synthesize partnerId;

@synthesize uploadFileTokenId;
@synthesize uploadFilePath;

@synthesize path, mwurl, mBitrates;

@synthesize delegate = _delegate;

+ (Client *)instance {
	static Client *sharedSingleton = nil;
	
	@synchronized(self) {
		if (!sharedSingleton) {
			sharedSingleton = [[Client alloc] initClient];
		}
	}
	return sharedSingleton;
}

- (id)initClient {
    
    KalturaClientConfiguration* config = [[KalturaClientConfiguration alloc] init];
    KalturaNSLogger* logger = [[KalturaNSLogger alloc] init];
    config.logger = logger;
    config.serviceUrl = DEFAULT_SERVICE_URL;
    [logger release];           // retained on config
    
    self.client = [[KalturaClient alloc] initWithConfig:config];
    [config release];           // retained on the client
    
    KalturaUserService *service = [[KalturaUserService alloc] init];
    service.client = self.client;
    
    NSString *userEmail = [[NSUserDefaults standardUserDefaults] objectForKey:@"userEmail"];
    NSString *userPassword = [[NSUserDefaults standardUserDefaults] objectForKey:@"userPassword"];
    
    
    self.client.ks = [service loginByLoginIdWithLoginId:userEmail withPassword:userPassword];
    
    [service release];
    
    KalturaUserListResponse *response = [self.client.user list];
    
    for (KalturaUser *user in [response objects]) {
        self.partnerId = user.partnerId;
    }
    
    self.categories = [[NSMutableArray alloc] init];
    self.media = [[NSMutableArray alloc] init];
    
    return self;
}

- (BOOL)login {
    
    [self.client release];
    
    KalturaClientConfiguration* config = [[KalturaClientConfiguration alloc] init];
    KalturaNSLogger* logger = [[KalturaNSLogger alloc] init];
    config.logger = logger;
    config.serviceUrl = DEFAULT_SERVICE_URL;
    [logger release];           // retained on config
    
    self.client = [[KalturaClient alloc] initWithConfig:config];
    [config release];           // retained on the client
    
    KalturaUserService *service = [[KalturaUserService alloc] init];
    service.client = self.client;
    
    
    NSString *userEmail = [[NSUserDefaults standardUserDefaults] objectForKey:@"userEmail"];
    NSString *userPassword = [[NSUserDefaults standardUserDefaults] objectForKey:@"userPassword"];
    
    self.client.ks = [service loginByLoginIdWithLoginId:userEmail withPassword:userPassword];
    
    [service release];
    
    KalturaUserListResponse *response = [self.client.user list];
    
    for (KalturaUser *user in [response objects]) {
        self.partnerId = user.partnerId;
    }
    
    [self.categories removeAllObjects];
    [self.media removeAllObjects];
    
    return ([self.client.ks length] > 0);
    
}

- (NSArray *)getCategories {
    
    if ([self.categories count] == 0) {
        
        KalturaCategoryListResponse *response = [self.client.category list];
        
        for (KalturaCategory *category in response.objects) {
            
            [self.categories addObject:category];
            
        }
        
    }
    
    
    return self.categories;
    
}

- (NSArray *)getMedia:(KalturaCategory *)category {
    
    if ([self.media count] == 0) {
        
        KalturaMediaEntryFilter *filter = [[KalturaMediaEntryFilter alloc] init];
        
        KalturaFilterPager *pager = [[KalturaFilterPager alloc] init];
        pager.pageSize = 0;
        
        KalturaMediaListResponse *response  = [self.client.media listWithFilter:filter withPager:pager];
        
        for (KalturaMediaEntry *mediaEntry in response.objects) {
            
            [self.media addObject:mediaEntry];
            
        }
        
        [filter release];
        [pager release];
        
    }
    
    return self.media;
    
}
- (NSString *)getThumbPath:(NSString *)fileName {
    
    NSError *error;
	
	NSString *thumbPath = [Utils getDocPath:@"Thumbs"];
	if (![[NSFileManager defaultManager] fileExistsAtPath:thumbPath])
		[[NSFileManager defaultManager] createDirectoryAtPath:thumbPath withIntermediateDirectories:NO attributes:nil error:&error]; //
    
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory , NSUserDomainMask, YES);
	NSString *docsDir = [paths objectAtIndex:0];
	docsDir = [docsDir stringByAppendingFormat:@"/Thumbs"];
	
	return [docsDir stringByAppendingPathComponent:fileName];
}

- (BOOL)isThumbExist:(KalturaMediaEntry *)mediaEntry {
    
    NSString *thumbPath = [self getThumbPath:mediaEntry.id];
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) {
        
        return YES;
    }
    
    return NO;
    
}

- (BOOL)isThumbNameExist:(NSString *)fileName {
    
    NSString *thumbPath = [self getThumbPath:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) {
        
        return YES;
    }
    
    return NO;
    
}

- (BOOL)isThumbExist:(KalturaMediaEntry *)mediaEntry width:(int)width height:(int)height {
    
    NSString *thumbPath = [NSString stringWithFormat:@"%@_%d_%d", mediaEntry.id, width, height];
    thumbPath = [self getThumbPath:thumbPath];
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) {
        
        return YES;
    }
    
    return NO;
    
}

- (NSData *)getThumb:(KalturaMediaEntry *)mediaEntry {
    
    NSString *thumbPath = [self getThumbPath:mediaEntry.id];
    if (![[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) {
        
        NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:mediaEntry.thumbnailUrl]];
        [data writeToFile:thumbPath atomically:NO];
        
        return data;
    }
    
    return [NSData dataWithContentsOfFile:thumbPath];
    
}

- (NSString *)getThumbURL:(NSString *)fileName width:(int)width height:(int)height {
    
    return [NSString stringWithFormat:@"http://cdn.kaltura.com/p/%d/thumbnail/entry_id/%@/width/%d/height/%d", self.partnerId, fileName, width, height];
    
}

- (NSString *)getShareURL:(KalturaMediaEntry *)mediaEntry {
    
    return [NSString stringWithFormat:@"http://prod.kaltura.co.cc/index.php/kmc/preview/partner_id/%d/uiconf_id/4630031/entry_id/%@/delivery/http", self.partnerId, mediaEntry.id];
    
}

- (void)shareFacebook:(KalturaMediaEntry *)mediaEntry {
    
    NSString *strURL = [NSString stringWithFormat:@"https://www.facebook.com/sharer/sharer.php?u=%@", [self getShareURL:mediaEntry]];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:strURL]];
    
}

- (void)shareTwitter:(KalturaMediaEntry *)mediaEntry {
    
    NSString *strURL = [NSString stringWithFormat:@"http://twitter.com/intent/tweet?url=%@", [self getShareURL:mediaEntry]];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:strURL]];
    
}

#pragma -
#pragma upload process

- (void)endUploading {
    [Utils deleteBufferFile];
    
    if (token) {
        
        [token release];
        
    }
    
    client.delegate = nil;
    client.uploadProgressDelegate = nil; 
}

- (void)cancelUploading {
    
    [client cancelRequest];
    
    [self endUploading];
}

- (BOOL)uploadingInProgress {
    
    return (uploadedSize > 0);  
}

- (void)uploadTry {
    
    uploadTryCount++;
    
    if (fileSize < CHUNK_SIZE)
    {
        uploadedSize = 0;
        token = [client.uploadToken uploadWithUploadTokenId:token.id withFileData:self.uploadFilePath];
    } else
    {
        uploadedSize = currentChunk * CHUNK_SIZE;
        
        token = [client.uploadToken uploadWithUploadTokenId:self.uploadFileTokenId withFileData:[Utils getDocPath:@"buffer.tmp"] withResume:(uploadedSize >= CHUNK_SIZE) withFinalChunk:(fileSize - uploadedSize <= CHUNK_SIZE) withResumeAt: uploadedSize];
    }
    
}

- (void)requestFinished:(KalturaClientBase*)aClient withResult:(id)result {
    
    currentChunk++;
    
    uploadedSize = currentChunk * CHUNK_SIZE;
    uploadTryCount = 0;
    
    if (uploadedSize < fileSize)
    {      
        [Utils createBuffer:uploadFilePath offset:uploadedSize];
        
        token = [client.uploadToken uploadWithUploadTokenId:self.uploadFileTokenId withFileData:[Utils getDocPath:@"buffer.tmp"] withResume:YES withFinalChunk:(fileSize - uploadedSize <= CHUNK_SIZE) withResumeAt: uploadedSize];
        
        return;
    }
    
    [self endUploading];
    
    [uploadDelegateController performSelector:@selector(uploadFinished)];
}

- (void)requestFailed:(KalturaClientBase*)aClient
{
    if (uploadTryCount < 4) {
        
        [self performSelector:@selector(uploadTry) withObject:nil afterDelay:2.0]; 
    }
    else
    {
        [self endUploading];
        
        [uploadDelegateController performSelector:@selector(uploadFailed)];
    }
}

- (void)request:(ASIHTTPRequest *)request didSendBytes:(long long)bytes {
    uploadedSize += bytes;
    
    [uploadDelegateController performSelector:@selector(updateProgress:) withObject:[NSNumber numberWithFloat:((float)(uploadedSize * 300 / fileSize) / 300.0)]];
}

- (void)uploadProcess:(NSDictionary *)data withDelegate:(UIViewController *)delegateController {
    
    uploadDelegateController = delegateController;
    self.uploadFilePath = [data objectForKey:@"path"];
    
    client.delegate = nil;
    
    token = [[KalturaUploadToken alloc] init];
    token.fileName = @"video.m4v";
    token = [client.uploadToken addWithUploadToken:token];
    
    KalturaMediaEntry* entry = [[[KalturaMediaEntry alloc] init] autorelease];
    entry.name = [data objectForKey:@"title"];
    entry.mediaType = [KalturaMediaType VIDEO];
    entry.categories = [data objectForKey:@"category"];
    entry.description = [data objectForKey:@"description"];
    entry.tags = [data objectForKey:@"tags"];
    
    entry = [client.media addWithEntry:entry];
    
    KalturaUploadedFileTokenResource* resource = [[[KalturaUploadedFileTokenResource alloc] init] autorelease];
    resource.token = token.id;
    entry = [client.media addContentWithEntryId:entry.id withResource:resource];
    
    client.delegate = self;
    client.uploadProgressDelegate = self;
    
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[data objectForKey:@"path"] error:nil];
    
    NSNumber *fileSizeNumber = [fileAttributes objectForKey:NSFileSize];
    fileSize = [fileSizeNumber longLongValue];
    uploadedSize = 0;
    uploadTryCount = 0;
    currentChunk = 0;
    
    self.uploadFileTokenId = token.id;
    
    if (fileSize < CHUNK_SIZE)
    {
        token = [client.uploadToken uploadWithUploadTokenId:token.id withFileData:self.uploadFilePath];
    }
    else
    {   
        [Utils createBuffer:[data objectForKey:@"path"] offset:0];
        
        token = [client.uploadToken uploadWithUploadTokenId:self.uploadFileTokenId withFileData:[Utils getDocPath:@"buffer.tmp"] withResume:NO withFinalChunk:NO];
    }
}

NSInteger bitratesSort(id media1, id media2, void *reverse)
{
	
	int bitrate1 = [[media1 objectForKey:@"bitrate"] intValue];
	int bitrate2 = [[media2 objectForKey:@"bitrate"] intValue];
	
	if (bitrate1 > bitrate2) {
		return NSOrderedAscending;
	} else {
		return NSOrderedDescending;
	}
}

- (NSArray *)getBitratesList:(KalturaMediaEntry *)mediaEntry withFilter:(NSString *)filter {
    
    NSMutableArray *bitrates = [[[NSMutableArray alloc] init] autorelease];
    
    KalturaAssetFilter *_filter = [[KalturaAssetFilter alloc] init];
    _filter.entryIdEqual = mediaEntry.id;
    KalturaFlavorAssetListResponse* _response = [client.flavorAsset listWithFilter:_filter];
    [_filter release];
    
    
    for (KalturaFlavorAsset *asset in _response.objects) {
        
        if ([asset.tags rangeOfString:filter].length > 0) {
            
            NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
            
            [dictionary setObject:asset.id forKey:@"id"];
            [dictionary setObject:[NSNumber numberWithInt:asset.bitrate] forKey:@"bitrate"];
            
            [bitrates addObject:dictionary];
            [dictionary release];
        } 
    }
    
    [bitrates sortUsingFunction:bitratesSort context:nil];
    
    return bitrates;
}

- (NSString *)getVideoURL:(KalturaMediaEntry *)mediaEntry forFlavor:(NSString *)flavorId forFlavorType: (NSString*)flavorType
{
    NSString *urlString;
    
    if([flavorType isEqual: @"wv"])
    {
        urlString = [NSString stringWithFormat:@"http://cdnbakmi.kaltura.com/p/%d/sp/%d00/serveFlavor/entryId/%@/v/2/flavorId/%@/name/a.wvm", partnerId, partnerId, mediaEntry.id, flavorId];
    }
    else
    {
        urlString = [NSString stringWithFormat:@"http://cdnbakmi.kaltura.com/p/%d/sp/%d00/playManifest/entryId/%@/flavorIds/%@/format/applehttp/protocol/http/a.mp4", partnerId, partnerId, mediaEntry.id, flavorId];
    }
    
    return urlString;
}

#pragma widevine support methods

- (void)donePlayingMovieWithWV
{
    [self.delegate videoStop];
    WV_Stop();
}

- (void)playMovieFromUrl:(NSString *)videoUrlString
{
    [path release];
    path = [videoUrlString retain];
    
    [[NSRunLoop mainRunLoop] addTimer:[NSTimer timerWithTimeInterval:0.1 target:self selector:@selector(playMovieFromUrlLater) userInfo:nil repeats:NO] forMode:NSDefaultRunLoopMode];
    
}

- (void)playMovieFromUrlLater
{
    
    NSMutableString *responseUrl = [NSMutableString string];
    WViOsApiStatus status = WV_Play(path, responseUrl, 0 );
    
    if (status != WViOsApiStatus_OK) {
        NSLog(@"%u",status);
        return;
    }
    
    mwurl = [NSURL URLWithString:responseUrl];
    NSLog(@"play later");
    
    [self.delegate videoPlay:mwurl];
}

- (NSDictionary*) initializeWVDictionary:(NSString *)flavorId{
    NSString* hostName;
    hostName= [[NSString alloc] initWithString: @"http://www.kaltura.com"];
    NSString* portalId, *drmServer;
    portalId = [[NSString alloc] initWithString: @"kaltura"];
    
    //EMM
    drmServer = [[NSString alloc] initWithFormat: @"%@/api_v3/index.php?service=widevine_widevinedrm&action=getLicense&format=widevine&flavorAssetId=%@&ks=%@" , hostName, flavorId, self.client.ks];
    [hostName release];
    
    NSDictionary* dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
                                drmServer, WVDRMServerKey,
                                portalId, WVPortalKey,
                                NULL];
    
    WV_Initialize(callback, dictionary);
    
    [portalId release];
    [drmServer release];
	
    return dictionary;
}

-(void)HandleCurrentBitrate:(NSDictionary *)attributes
{
    if (sBitRates == nil) {
		[attributes release];
        return;
    }
    NSNumber *number = [attributes objectForKey:WVCurrentBitrateKey];
    if ( number == nil) {
		[attributes release];
        return;
    }
    
    mSettingBitRateButton = true;
    long curBitRate = [number longValue];
    
    int idx, end;
    end = [sBitRates count];
    for ( idx = 0; idx < end; ++idx ) {
        if ( [[sBitRates objectAtIndex:idx] longValue] >= curBitRate) {
            mBitrates.selectedSegmentIndex = idx;
            break;
        }
    }
    
    mBitrates.selectedSegmentIndex = [number intValue];
    mSettingBitRateButton = false;
    [attributes release];
}

WViOsApiStatus callback( WViOsApiEvent event, NSDictionary *attributes )
{
    NSLog( @"callback %d %@\n", event, NSStringFromWViOsApiEvent( event ) );
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; SEL selector = 0;
    switch ( event ) {
        case WViOsApiEvent_SetCurrentBitrate:
            selector = NSSelectorFromString(@"HandleCurrentBitrate:");
            break;
        case WViOsApiEvent_Bitrates:
            selector = NSSelectorFromString(@"HandleBitrates:");
            break;
        case WViOsApiEvent_ChapterTitle:
            selector = NSSelectorFromString(@"HandleChapterTitle:");
            break;
        case WViOsApiEvent_ChapterImage:
            selector = NSSelectorFromString(@"HandleChapterImage:");
            break;
        case WViOsApiEvent_ChapterSetup:
            selector = NSSelectorFromString(@"HandleChapterSetup:");
            break;
    }
    
    if ( selector ) {
        [attributes retain];
    }
    
    [pool release];
    NSLog(@"widvine callback");
    
    return WViOsApiStatus_OK;
}

-(void)HandleBitrates:(NSDictionary *)attributes
{
    NSArray *bitrates = [attributes objectForKey:WVBitratesKey];
    [mBitrates removeAllSegments];
    if ( bitrates ) {
        [sBitRates release];
        sBitRates = [bitrates retain];
        int count, end;
        end = [bitrates count];
        for ( count = 0; count < end; ++count ) {
            NSString *label;
            long bps = [[bitrates objectAtIndex:count] longLongValue] * 8;
            if ( bps < 1000 ) {
                label = [NSString stringWithFormat:@"%ldbps",bps,NULL];
            } else if ( bps < 1000000 ) {
                label = [NSString stringWithFormat:@"%2.1fkbs",(float)bps/1000,NULL];
			} else {
                label = [NSString stringWithFormat:@"%2.1fmbs",(float)bps/1000000,NULL];
			}
            
			[mBitrates insertSegmentWithTitle:label atIndex:count animated:NO];
        }
        
    }
    [attributes release];
}

@end

