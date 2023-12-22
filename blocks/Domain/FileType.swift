//
//  FileType.swift
//  blocks
//
//  Created by よういち on 2023/11/02.
//  Copyright © 2023 WEB BANANA UNITE Tokyo-Yokohama LPC. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

public enum FileType: String {
    case zip, audio, movie                  //known files
    case key, numbers, pages                //iWork documents
    case doc, docx, xls, xlsx, ppt, pptx    //Microsoft Office documents
    case rtf                                //Rich text format, or RTF, documents
    case pdf                                //PDF files
    case png, jpg, jpeg, gif, tiff, bmp     //Images
    case txt, json, yaml                    //Text files with a uniform type identifier that conforms to the public.text type.
    case csv    //Comma-separated values, or CSV, files
    case usdz   //3D models in the USDZ format with both standalone and AR views for viewing the model

    /*
     .fileImporter#allowedContentTypes: [.zip, .rtfd, .image, .audio, .movie, .text, .pdf, .json, .yaml]
     */
    public static var importable: [UTType] {
        [.zip, .rtf, .image, .audio, .movie, .text, .pdf, .json, .yaml]
    }
    
    var withPeriod: String {
        "." + self.rawValue
    }
}
