package com.songsterq.reactnative

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import com.facebook.react.bridge.*
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.rendering.PDFRenderer
import com.tom_roush.pdfbox.rendering.ImageType;
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader;
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.util.*
import java.io.BufferedInputStream

class PdfThumbnailModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {

  override fun getName(): String {
    return "PdfThumbnail"
  }

  @ReactMethod
  fun generate(filePath: String, page: Int, quality: Int, promise: Promise) {
    var parcelFileDescriptor: ParcelFileDescriptor? = null
    var pdfRenderer: PdfRenderer? = null
    try {
      parcelFileDescriptor = getParcelFileDescriptor(filePath)
      if (parcelFileDescriptor == null) {
        promise.reject("FILE_NOT_FOUND", "File $filePath not found")
        return
      }

      pdfRenderer = PdfRenderer(parcelFileDescriptor)
      if (page < 0 || page >= pdfRenderer.pageCount) {
        promise.reject("INVALID_PAGE", "Page number $page is invalid, file has ${pdfRenderer.pageCount} pages")
        return
      }
      val document = PDDocument.load(File(filePath))
      val result = renderPage(pdfRenderer,document, page, filePath, quality)
      document.close()
      promise.resolve(result)
    } catch (ex: IOException) {
      promise.reject("INTERNAL_ERROR", ex)
    } finally {
      pdfRenderer?.close()
      parcelFileDescriptor?.close()
    }
  }

  @ReactMethod
  fun generateAllPages(filePath: String, quality: Int, promise: Promise) {
    PDFBoxResourceLoader.init(this.reactApplicationContext);
    var parcelFileDescriptor: ParcelFileDescriptor? = null
    var pdfRenderer: PdfRenderer? = null
    try {
      parcelFileDescriptor = getParcelFileDescriptor(filePath)
      if (parcelFileDescriptor == null) {
        promise.reject("FILE_NOT_FOUND", "File $filePath not found")
        return
      }

      val document = PDDocument.load(File(filePath))

      pdfRenderer = PdfRenderer(parcelFileDescriptor)
      val result = WritableNativeArray()
      for (page in 0 until pdfRenderer.pageCount) {
        result.pushMap(renderPage(pdfRenderer,document, page, filePath, quality))
      }

      document.close()
      promise.resolve(result)
    } catch (ex: IOException) {
      promise.reject("INTERNAL_ERROR", ex)
    } finally {
      pdfRenderer?.close()
      parcelFileDescriptor?.close()
    }
  }

  private fun getParcelFileDescriptor(filePath: String): ParcelFileDescriptor? {
    val uri = Uri.parse(filePath)
    if (ContentResolver.SCHEME_CONTENT == uri.scheme || ContentResolver.SCHEME_FILE == uri.scheme) {
      return this.reactApplicationContext.contentResolver.openFileDescriptor(uri, "r")
    } else if (filePath.startsWith("/")) {
      val file = File(filePath)
      return ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
    }
    //error : open failed
//    else if (filePath.startsWith("http") || filePath.startsWith("https")) {
//      try {
//        val cacheDir = this.reactApplicationContext.cacheDir
//        cacheDir.mkdirs() // Ensure cache directory exists
//
//        val url = URL(filePath)
//        val connection = url.openConnection() as HttpURLConnection
//        val inputStream = BufferedInputStream(connection.inputStream)
//        val outputFile = File(cacheDir, "temp.pdf")
//        val outputStream = FileOutputStream(outputFile)
//
//        inputStream.use { input ->
//          outputStream.use { output ->
//            input.copyTo(output)
//          }
//        }
//
//        return ParcelFileDescriptor.open(outputFile, ParcelFileDescriptor.MODE_READ_ONLY)
//      } catch (e: Exception) {
//        e.printStackTrace()
//      }
//    }
    return null
  }

  private fun renderPage(pdfRenderer: PdfRenderer,document: PDDocument, page: Int, filePath: String, quality: Int): WritableNativeMap {
    val currentPage = pdfRenderer.openPage(page)
    val scaleFactor = 2f // Scale factor for rendering the bitmap

    val width = (currentPage.width * scaleFactor).toInt()
    val height = (currentPage.height * scaleFactor).toInt()
    currentPage.close()

    val renderer = PDFRenderer(document)
    // Render the image to an RGB Bitmap
    val pageImage = renderer.renderImage(page, 2f, ImageType.RGB)

    val outputFile = File.createTempFile(getOutputFilePrefix(filePath, page), ".png", reactApplicationContext.cacheDir)
    if (outputFile.exists()) {
      outputFile.delete()
    }
    val out = FileOutputStream(outputFile)
    pageImage.compress(Bitmap.CompressFormat.JPEG, 100, out);
    out.flush()
    out.close()

    val map = WritableNativeMap()
    map.putString("uri", Uri.fromFile(outputFile).toString())
    map.putInt("width", width)
    map.putInt("height", height)
    return map
  }

  private fun getOutputFilePrefix(filePath: String, page: Int): String {
    val tokens = filePath.split("/")
    val originalFilename = tokens[tokens.lastIndex]
    val prefix = originalFilename.replace(".", "-")
    val generator = Random()
    val random = generator.nextInt(Integer.MAX_VALUE)
    return "$prefix-thumbnail-$page-$random"
  }
}
