import PDFKit
import Foundation

@available(iOS 11.0, *)
@objc(PdfThumbnail)
class PdfThumbnail: NSObject {

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }

    lazy var cachesDirectoryURL: URL = {
        guard let url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {
                fatalError("Unable to retrieve caches directory URL")
            }
        return url
    }()

    func getCachesDirectory() -> URL {
//        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
//        return paths[0]
        return cachesDirectoryURL
    }

    func getOutputFilename(filePath: String, page: Int) -> String {
//        let components = filePath.components(separatedBy: "/")
        var prefix: String
//        if let origionalFileName = components.last {
//            prefix = String(
//                origionalFileName.replacingOccurrences(
//                    of: "[^a-zA-Z0-9]", // This regex matches any character that is not a letter or a digit
//                    with: "-",
//                    options: .regularExpression,
//                    range: nil
//                ).prefix(20)
//            )
//        } else {
//            prefix = "pdf"
//        }

        prefix = UUID().uuidString

        let random = Int.random(in: 0 ..< Int.max)
        return "\(prefix)-thumbnail-\(page)-\(random).jpg"
    }

    func generatePage(pdfPage: PDFPage, filePath: String, page: Int, quality: Int) -> Dictionary<String, Any>? {
//        let pageRect = pdfPage.bounds(for: .mediaBox)
//        let imageSize = CGSize(width: pageRect.width * 2, height: pageRect.height * 2)
//        let image = pdfPage.thumbnail(of: imageSize, for: .mediaBox)
//        var outputFile = getCachesDirectory().appendingPathComponent(getOutputFilename(filePath: filePath, page: page))
//        guard let data = image.jpegData(compressionQuality: CGFloat(quality) / 100) else {
//            return nil
//        }
//
//        defer {
//                // Close the file after writing data
//                // This block will be executed before the function returns
//                // regardless of how the function exits
//            outputFile.deletePathExtension()
//            }
//
//        do {
//            try data.write(to: outputFile)
//            return [
//                "uri": outputFile.absoluteString,
//                "width": Int(pageRect.width),
//                "height": Int(pageRect.height),
//            ]
//        } catch {
//            return nil
//        }
        autoreleasepool {
            let pageRect = pdfPage.bounds(for: .mediaBox)
            let imageSize = CGSize(width: pageRect.width, height: pageRect.height)

            // Generate the thumbnail image
            let image = pdfPage.thumbnail(of: imageSize, for: .mediaBox)

            let outputFile = getCachesDirectory().appendingPathComponent(getOutputFilename(filePath: filePath, page: page))

            // Reduce the image size for memory efficiency
            let resizedImage = image.resized(to: imageSize, pageRect: pageRect, pdfPage: pdfPage)

            // Convert the resized image to JPEG data with specified compression quality
            let data = resizedImage?.jpegData(compressionQuality: CGFloat(quality))

            do {
                try data?.write(to: outputFile)
                let outputURLString = outputFile.absoluteString


                return [
                    "uri": outputURLString,
                    "width": Int(pageRect.width),
                    "height": Int(pageRect.height),
                ]
            } catch {
                return nil
            }
        }
    }

    @available(iOS 11.0, *)
    @objc(generate:withPage:withQuality:withResolver:withRejecter:)
    func generate(filePath: String, page: Int, quality: Int, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        guard let fileUrl = URL(string: filePath) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfDocument = PDFDocument(url: fileUrl) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfPage = pdfDocument.page(at: page) else {
            reject("INVALID_PAGE", "Page number \(page) is invalid, file has \(pdfDocument.pageCount) pages", nil)
            return
        }

        if let pageResult = generatePage(pdfPage: pdfPage, filePath: filePath, page: page, quality: quality) {
            resolve(pageResult)
        } else {
            reject("INTERNAL_ERROR", "Cannot write image data", nil)
        }
    }

    @available(iOS 11.0, *)
    @objc(generateAllPages:withQuality:withResolver:withRejecter:)
    func generateAllPages(filePath: String, quality: Int, resolve:RCTPromiseResolveBlock, reject:RCTPromiseRejectBlock) -> Void {
        guard let fileUrl = URL(string: filePath) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }
        guard let pdfDocument = PDFDocument(url: fileUrl) else {
            reject("FILE_NOT_FOUND", "File \(filePath) not found", nil)
            return
        }

        var result: [Dictionary<String, Any>] = []
        for page in 0..<pdfDocument.pageCount {
            guard let pdfPage = pdfDocument.page(at: page) else {
                reject("INVALID_PAGE", "Page number \(page) is invalid, file has \(pdfDocument.pageCount) pages", nil)
                return
            }
            if let pageResult = generatePage(pdfPage: pdfPage, filePath: filePath, page: page, quality: quality) {
                result.append(pageResult)
            } else {
                reject("INTERNAL_ERROR", "Cannot write image data", nil)
                return
            }
        }
        resolve(result)
    }
}

extension UIImage {
    func resized(to size: CGSize, pageRect: CGRect,pdfPage: PDFPage) -> UIImage? {
         let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Set and fill the background color.
            UIColor.white.set()
            ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))

            // Translate the context so that we only draw the `cropRect`.
            ctx.cgContext.translateBy(x: -pageRect.origin.x, y: pageRect.size.height - pageRect.origin.y)

            // Flip the context vertically because the Core Graphics coordinate system starts from the bottom.
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)

            pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
        }
    }
}
