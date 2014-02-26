//  main.m
//  compareimages
//
//  Created by Kevin Meaney on 25/02/2014.
//  Copyright (c) 2014 Kevin Meaney. All rights reserved.

@import Foundation;
@import QuartzCore;

// ---------------------------------------------------------------------------
//		YVSCompareImageFilesProcessor Class Interface
// ---------------------------------------------------------------------------

@interface YVSCompareImageFilesProcessor : NSObject
{
    CGContextRef cgContext;
}

@property (nonatomic, strong) NSString *programName;
@property (nonatomic, strong) NSString *exportType; // hard coded to png or tiff
@property (nonatomic, assign) float distance;
@property (nonatomic, strong) NSURL *file1;
@property (nonatomic, strong) NSURL *file2;
@property (nonatomic, assign) BOOL areEqual;

-(id)initWithArgs:(int)argc argv:(const char **)argv;
+(void)printUsage;
-(int)compareFiles;
-(int)run;

@end

void SaveCGImageToAPNGFile(CGImageRef theImage, NSString *fileName)
{
    NSString *df = @"~/Desktop/junkimages";
    NSString *destination = [NSString stringWithFormat:@"%@/%@",
                             [df stringByExpandingTildeInPath], fileName];
    
    NSURL *fileURL = [[NSURL alloc] initFileURLWithPath:destination];
    CGImageDestinationRef exporter = CGImageDestinationCreateWithURL(
                                                     (__bridge CFURLRef)fileURL,
                                                     kUTTypePNG, 1, NULL);
    CGImageDestinationAddImage(exporter, theImage, nil);
    CGImageDestinationFinalize(exporter);
    CFRelease(exporter);
}

void SaveCGBitmapContextToAPNGFile(CGContextRef context, NSString *fileName)
{
    CGImageRef image = CGBitmapContextCreateImage(context);
    SaveCGImageToAPNGFile(image, fileName);
    CGImageRelease(image);
}

void SaveCIImageToAPNGFile(CIImage *ciImage, NSString *fileName)
{
    CGRect extent = [ciImage extent];
    size_t width = extent.size.width;
    size_t height = extent.size.height;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);

    CGContextRef context = CGBitmapContextCreate(nil, width, height, 32,
                                 width * 16, colorSpace,
                                 kCGBitmapFloatComponents +
                                 (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CIContext *ciContext = [CIContext contextWithCGContext:context options:nil];
    [ciContext drawImage:ciImage inRect:extent fromRect:extent];
    SaveCGBitmapContextToAPNGFile(context, fileName);
}

BOOL GetCGFloatFromString(NSString *string, CGFloat *value)
{
    NSScanner *scanner = [[NSScanner alloc] initWithString:string];
    CGFloat floatVal;
#if defined(__LP64__) && __LP64__
    BOOL gotValue = [scanner scanDouble:&floatVal];
#else
    BOOL gotValue = [scanner scanFloat:&floatVal];
#endif
    if (gotValue)
    {
        *value = floatVal;
    }
    return gotValue;
}

/*
void DrawTransparentBlackToContext(CGContextRef context, size_t width,
                                   size_t height)
{
    // Now redraw to the context with transparent black.
    CGContextSaveGState(context);
    CGColorRef tBlack = CGColorCreateGenericRGB(0.0, 0.0, 0.0, 0.0);
    CGContextSetBlendMode(context, kCGBlendModeCopy);
    CGContextSetFillColorWithColor(context, tBlack);
    CGColorRelease(tBlack);
    CGRect theRect = CGRectMake(0.0, 0.0, width, height);
    CGContextFillRect(context, theRect);
    CGContextRestoreGState(context);
}
*/

CGFloat ClipFloatToMinMax(CGFloat in, CGFloat min, CGFloat max)
{
    if (in > max)
        return max;
    if (in < min)
        return min;
    return in;
}

@implementation YVSCompareImageFilesProcessor

-(instancetype)initWithArgs:(int)argc argv:(const char **)argv
{
    self = [super init];
    if (self)
    {
        self.exportType = @"public.png";
        self.distance = 0.1;
        // self.exportType = @"public.tiff";
        // Processing the args goes here.
        BOOL gotFile1 = NO;
        BOOL gotFile2 = NO;   // Folder to save files.
        
        [self setProgramName:@(*argv++)];
        
        argc--;
        while (argc > 0 && **argv == '-' )
        {
            const char *args = *argv;
            
            argc--;
            argv++;
            
            if (!strcmp(args, "-file1"))
            {
                argc--;
                if (argc >= 0)
                {
                    NSString *sourcePath = @(*argv++);
                    sourcePath = [sourcePath stringByExpandingTildeInPath];
                    NSURL *url = [[NSURL alloc] initFileURLWithPath:sourcePath];
                    self.file1 = url;
                    if (self.file1)
                    {
                        gotFile1 = YES;
                    }
                }
            }
            else if (!strcmp(args, "-file2"))
            {
                argc--;
                if (argc >= 0)
                {
                    NSString *file2Str = @(*argv++);
                    file2Str = [file2Str stringByExpandingTildeInPath];
                    NSURL *destURL = [[NSURL alloc] initFileURLWithPath:file2Str];
                    self.file2 = destURL;
                    if (self.file2)
                    {
                        gotFile2 = YES;
                    }
                }
            }
            else if (!strcmp(args, "-distance"))
            {
                argc--;
                if (argc >= 0)
                {
                    CGFloat dist;
                    NSString *distance = @(*argv++);
                    
                    BOOL gotDistance = GetCGFloatFromString(distance, &dist);
                    if (gotDistance)
                    {
                        dist = ClipFloatToMinMax(dist, 0.0, 1.7);
                        self.distance = dist;
                    }
                    else
                        self.distance = 0.1;
                }
            }
        }
        if (!(gotFile1 && gotFile2))
        {
            self = nil;
            return self;
        }
    }
    return self;
}

-(int)compareFiles
{
    int result = 0;
    
    // Create the image importer, and exit on failure.
    CGImageSourceRef imageSource1, imageSource2;
    imageSource1 = CGImageSourceCreateWithURL((__bridge CFURLRef)self.file1, nil);
    if (!(imageSource1 && CGImageSourceGetCount(imageSource1)))
    {
        result = -2;
        if (imageSource1)
        {
            CFRelease(imageSource1);
        }
        return result;
    }
    
    // Create the image from the image source and exit on failure.
    CGImageRef image1 = CGImageSourceCreateImageAtIndex(imageSource1, 0, nil);
    CFRelease(imageSource1);
    if (!image1)
    {
        result = -3;
        return result;
    }

    imageSource2 = CGImageSourceCreateWithURL((__bridge CFURLRef)self.file2, nil);
    if (!(imageSource2 && CGImageSourceGetCount(imageSource2)))
    {
        result = -2;
        if (imageSource2)
        {
            CFRelease(imageSource2);
        }
        CGImageRelease(image1);
        return result;
    }
    
    // Create the image from the image source and exit on failure.
    CGImageRef image2 = CGImageSourceCreateImageAtIndex(imageSource2, 0, nil);
    CFRelease(imageSource2);
    if (!image2)
    {
        result = -3;
        CGImageRelease(image1);
        return result;
    }
    
    // Get an already created graphic context or create a new one if necessary.
    size_t imageWidth1 = CGImageGetWidth(image1);
    size_t imageHeight1 = CGImageGetHeight(image1);
    
    // Get an already created graphic context or create a new one if necessary.
    size_t imageWidth2 = CGImageGetWidth(image2);
    size_t imageHeight2 = CGImageGetHeight(image2);
    
    if (imageWidth1 != imageWidth2 || imageHeight1 != imageHeight2)
    {
        // Different dimensions, for this purposes the images are different.
        CGImageRelease(image1);
        CGImageRelease(image2);
        self.areEqual = NO;
        return result;
    }

    CIFilter *diffFilter = [CIFilter filterWithName:@"CIDifferenceBlendMode"];
    [diffFilter setValue:[CIImage imageWithCGImage:image1] forKey:@"inputImage"];
    [diffFilter setValue:[CIImage imageWithCGImage:image2] forKey:@"inputBackgroundImage"];
    
    CIFilter *areaMaxFilter = [CIFilter filterWithName:@"CIAreaMaximum"];
    [areaMaxFilter setDefaults];
    CIImage *intermediateImage = [diffFilter valueForKey:@"outputImage"];
    SaveCIImageToAPNGFile(intermediateImage, @"deleteme.png");
    [areaMaxFilter setValue:intermediateImage forKey:@"inputImage"];
    CGRect fromRect = CGRectMake(0.0, 0.0,
                                 (CGFloat)imageWidth1, (CGFloat)imageHeight1);
    CIVector *extentVector = [[CIVector alloc] initWithCGRect:fromRect];
    [areaMaxFilter setValue:extentVector forKey:@"inputExtent"];
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    // CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    //    float buff[4] = { 1.0, 1.0, 1.0, 1.0 };
    unsigned char buff[4];
    CGContextRef context = CGBitmapContextCreate(buff, 1, 1, 8, 16, colorSpace,
    //CGContextRef context = CGBitmapContextCreate(buff, 1, 1, 32, 16, colorSpace,
    //                                                kCGBitmapFloatComponents +
                                    (CGBitmapInfo)kCGImageAlphaPremultipliedLast);

    NSDictionary *ciContextOptions;
    ciContextOptions = @{ kCIContextWorkingColorSpace : (__bridge id)colorSpace,
                          kCIContextUseSoftwareRenderer : @NO };
    CIContext *ciContext = [CIContext contextWithCGContext:context
                                                   options:ciContextOptions];
    CGColorSpaceRelease(colorSpace);
    
    // Get the CIImage from the filter.
    CIImage *outImage = [areaMaxFilter valueForKey:kCIOutputImageKey];
    // CGRect inRect = CGRectMake(0.0, 0.0, 1.0, 1.0);
    CGRect outExtent = [outImage extent];
    [ciContext drawImage:outImage inRect:outExtent fromRect:outExtent];
    CGImageRelease(image1);
    CGImageRelease(image2);
    diffFilter = nil;
    areaMaxFilter = nil;
    extentVector = nil;
    // Check the alpha channel as well as all the others.
    //    if (buff[0] < self.distance && buff[1] < self.distance && buff[2] < self.distance)
    // self.areEqual = YES;
    
    unsigned char dist = 255 * self.distance;
    if (buff[0] < dist && buff[1] < dist && buff[2] < dist)
        self.areEqual = YES;

    CGContextRelease(context);
    return result;
}

-(int)run
{
    int result = [self compareFiles];
    return result;
}

+(void)printUsage
{
    printf("compareimages - usage:\n");
    printf("Not yet implemented.\n");
}

@end

int main(int argc, const char * argv[])
{
    int result = -1;
    BOOL areEqual;
    @autoreleasepool
    {
        //	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
        @autoreleasepool
        {
            YVSCompareImageFilesProcessor* processor;
            processor = [[YVSCompareImageFilesProcessor alloc] initWithArgs:argc
                                                                    argv:argv];
            if (processor)
            {
                result = [processor run];
                areEqual = processor.areEqual;
            }
            else
                [YVSCompareImageFilesProcessor printUsage];
        }
    }
    if (result == 0)
        printf("Equal: %s\n", areEqual ? "YES" : "NO");
    return result;
}
