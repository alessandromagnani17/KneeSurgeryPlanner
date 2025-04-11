#import "DCMTKBridge.h"

// Include delle librerie DCMTK
#include "dcmtk/config/osconfig.h"
#include "dcmtk/dcmdata/dctk.h"
#include "dcmtk/dcmimgle/dcmimage.h"
#include "dcmtk/dcmdata/dcfilefo.h"
#include "dcmtk/dcmdata/dcitem.h"
#include "dcmtk/dcmdata/dcdeftag.h"

@implementation DCMTKBridge

// Legge tutti i metadati DICOM e li restituisce come dizionario
+ (NSDictionary *)readMetadataFromFile:(NSString *)filePath {
    NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
    
    const char *filename = [filePath UTF8String];
    DcmFileFormat fileformat;
    OFCondition status = fileformat.loadFile(filename);
    
    if (status.good()) {
        DcmDataset *dataset = fileformat.getDataset();
        
        // Leggi i metadati principali
        OFString patientName, patientID, modality, studyDate;
        OFString seriesDescription, seriesInstanceUID;
        
        if (dataset->findAndGetOFString(DCM_PatientName, patientName).good()) {
            metadata[@"PatientName"] = [NSString stringWithUTF8String:patientName.c_str()];
        }
        
        if (dataset->findAndGetOFString(DCM_PatientID, patientID).good()) {
            metadata[@"PatientID"] = [NSString stringWithUTF8String:patientID.c_str()];
        }
        
        if (dataset->findAndGetOFString(DCM_Modality, modality).good()) {
            metadata[@"Modality"] = [NSString stringWithUTF8String:modality.c_str()];
        }
        
        if (dataset->findAndGetOFString(DCM_StudyDate, studyDate).good()) {
            metadata[@"StudyDate"] = [NSString stringWithUTF8String:studyDate.c_str()];
        }
        
        if (dataset->findAndGetOFString(DCM_SeriesDescription, seriesDescription).good()) {
            metadata[@"SeriesDescription"] = [NSString stringWithUTF8String:seriesDescription.c_str()];
        }
        
        if (dataset->findAndGetOFString(DCM_SeriesInstanceUID, seriesInstanceUID).good()) {
            metadata[@"SeriesInstanceUID"] = [NSString stringWithUTF8String:seriesInstanceUID.c_str()];
        }
        
        // Aggiungi informazioni sull'immagine
        unsigned short rows = 0, columns = 0, bitsAllocated = 0, bitsStored = 0;
        
        if (dataset->findAndGetUint16(DCM_Rows, rows).good()) {
            metadata[@"Rows"] = @(rows);
        }
        
        if (dataset->findAndGetUint16(DCM_Columns, columns).good()) {
            metadata[@"Columns"] = @(columns);
        }
        
        if (dataset->findAndGetUint16(DCM_BitsAllocated, bitsAllocated).good()) {
            metadata[@"BitsAllocated"] = @(bitsAllocated);
        }
        
        if (dataset->findAndGetUint16(DCM_BitsStored, bitsStored).good()) {
            metadata[@"BitsStored"] = @(bitsStored);
        }
        
        // Leggi la spaziatura tra pixel
        OFString pixelSpacingStr;
        if (dataset->findAndGetOFString(DCM_PixelSpacing, pixelSpacingStr, 0).good()) {
            NSString *spacingString = [NSString stringWithUTF8String:pixelSpacingStr.c_str()];
            NSArray *spacingComponents = [spacingString componentsSeparatedByString:@"\\"];
            
            if (spacingComponents.count >= 2) {
                metadata[@"PixelSpacingX"] = spacingComponents[0];
                metadata[@"PixelSpacingY"] = spacingComponents[1];
            }
        }
        
        // Leggi la posizione dell'immagine
        OFString imagePositionStr;
        if (dataset->findAndGetOFString(DCM_ImagePositionPatient, imagePositionStr, 0).good()) {
            NSString *positionString = [NSString stringWithUTF8String:imagePositionStr.c_str()];
            NSArray *positionComponents = [positionString componentsSeparatedByString:@"\\"];
            
            if (positionComponents.count >= 3) {
                metadata[@"ImagePositionX"] = positionComponents[0];
                metadata[@"ImagePositionY"] = positionComponents[1];
                metadata[@"ImagePositionZ"] = positionComponents[2];
            }
        }
        
        // Leggi l'orientamento dell'immagine
        OFString imageOrientationStr;
        if (dataset->findAndGetOFString(DCM_ImageOrientationPatient, imageOrientationStr, 0).good()) {
            NSString *orientationString = [NSString stringWithUTF8String:imageOrientationStr.c_str()];
            NSMutableArray *orientationComponents = [[orientationString componentsSeparatedByString:@"\\"] mutableCopy];
            
            if (orientationComponents.count >= 6) {
                NSMutableArray *orientation = [NSMutableArray arrayWithCapacity:6];
                for (NSString *value in orientationComponents) {
                    [orientation addObject:@([value doubleValue])];
                }
                metadata[@"ImageOrientation"] = orientation;
            }
        }
        
        // Window Center/Width per visualizzazione
        OFString windowCenterStr, windowWidthStr;
        if (dataset->findAndGetOFString(DCM_WindowCenter, windowCenterStr, 0).good()) {
            metadata[@"WindowCenter"] = [NSString stringWithUTF8String:windowCenterStr.c_str()];
        }
        
        if (dataset->findAndGetOFString(DCM_WindowWidth, windowWidthStr, 0).good()) {
            metadata[@"WindowWidth"] = [NSString stringWithUTF8String:windowWidthStr.c_str()];
        }
        
        // SliceLocation
        OFString sliceLocationStr;
        if (dataset->findAndGetOFString(DCM_SliceLocation, sliceLocationStr, 0).good()) {
            metadata[@"SliceLocation"] = [NSString stringWithUTF8String:sliceLocationStr.c_str()];
        }
        
        // InstanceNumber
        OFString instanceNumberStr;
        if (dataset->findAndGetOFString(DCM_InstanceNumber, instanceNumberStr, 0).good()) {
            metadata[@"InstanceNumber"] = [NSString stringWithUTF8String:instanceNumberStr.c_str()];
        }
    }
    
    return metadata;
}

// Ottiene il valore di un tag specifico
+ (NSString *)getTagValue:(NSString *)filePath tagName:(NSString *)tagName {
    const char *filename = [filePath UTF8String];
    DcmFileFormat fileformat;
    OFCondition status = fileformat.loadFile(filename);
    
    if (status.good()) {
        DcmDataset *dataset = fileformat.getDataset();
        DcmTagKey tagKey;
        
        // Mappa nomi di tag comuni ai loro codici DICOM
        if ([tagName isEqualToString:@"PatientName"]) {
            tagKey = DCM_PatientName;
        } else if ([tagName isEqualToString:@"PatientID"]) {
            tagKey = DCM_PatientID;
        } else if ([tagName isEqualToString:@"Modality"]) {
            tagKey = DCM_Modality;
        } else if ([tagName isEqualToString:@"StudyDate"]) {
            tagKey = DCM_StudyDate;
        } else {
            return @"Tag non supportato";
        }
        
        OFString value;
        if (dataset->findAndGetOFString(tagKey, value).good()) {
            return [NSString stringWithUTF8String:value.c_str()];
        }
    }
    
    return @"Tag non trovato";
}

// Ottiene i dati dei pixel dall'immagine DICOM
+ (NSData *)getPixelDataFromFile:(NSString *)filePath rows:(int *)rows columns:(int *)columns bitsAllocated:(int *)bitsAllocated {
    const char *filename = [filePath UTF8String];
    DcmFileFormat fileformat;
    OFCondition status = fileformat.loadFile(filename);
    
    if (status.good()) {
        DcmDataset *dataset = fileformat.getDataset();
        
        // Ottiene le dimensioni dell'immagine
        unsigned short rowsValue = 0, columnsValue = 0, bitsValue = 0;
        dataset->findAndGetUint16(DCM_Rows, rowsValue);
        dataset->findAndGetUint16(DCM_Columns, columnsValue);
        dataset->findAndGetUint16(DCM_BitsAllocated, bitsValue);
        
        *rows = (int)rowsValue;
        *columns = (int)columnsValue;
        *bitsAllocated = (int)bitsValue;
        
        // Recupera i dati dei pixel
        const Uint8 *pixelData = nullptr;
        unsigned long length = 0;
        
        if (dataset->findAndGetUint8Array(DCM_PixelData, pixelData, &length).good()) {
            return [NSData dataWithBytes:pixelData length:length];
        }
    }
    
    return nil;
}

// Stampa tutti i tag per debug
+ (void)printAllTagsFromFile:(NSString *)filePath {
    const char *filename = [filePath UTF8String];
    DcmFileFormat fileformat;
    OFCondition status = fileformat.loadFile(filename);
    
    if (status.good()) {
        DcmDataset *dataset = fileformat.getDataset();
        
        // Itera su tutti gli elementi
        NSLog(@"===== DICOM Tags for %@ =====", [filePath lastPathComponent]);
        
        for (unsigned long i = 0; i < dataset->card(); i++) {
            DcmElement *element = dataset->getElement(i);
            if (element) {
                DcmTag tag = element->getTag();
                OFString value;
                
                element->getOFStringArray(value);
                
                NSLog(@"Tag: (%04x,%04x) %s = %s",
                      tag.getGTag(), tag.getETag(),
                      tag.getTagName(),
                      value.c_str());
            }
        }
        
        NSLog(@"===== End of DICOM Tags =====");
    } else {
        NSLog(@"Errore nell'apertura del file DICOM: %s", status.text());
    }
}

@end
