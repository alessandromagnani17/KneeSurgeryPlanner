#ifndef DCMTKBridge_h
#define DCMTKBridge_h

#import <Foundation/Foundation.h>

// Classe Objective-C che fa da bridge con DCMTK
@interface DCMTKBridge : NSObject

// Metodi per leggere metadati DICOM
+ (NSDictionary *)readMetadataFromFile:(NSString *)filePath;
+ (NSString *)getTagValue:(NSString *)filePath tagName:(NSString *)tagName;
+ (NSData *)getPixelDataFromFile:(NSString *)filePath rows:(int *)rows columns:(int *)columns bitsAllocated:(int *)bitsAllocated;

// Metodo per il debug
+ (void)printAllTagsFromFile:(NSString *)filePath;

@end

#endif /* DCMTKBridge_h */
