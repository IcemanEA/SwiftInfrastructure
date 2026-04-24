//
//  ImageMetadataService.swift
//  SwiftInfrastructure
//
//  Created by Egor Ledkov on 04.07.2025.
//

import UIKit
import ImageIO

/// A service for reading image metadata (dimensions, aspect ratio) without a full decode.
public final class ImageMetadataService {

	/// Returns the pixel dimensions of an image on disk, reading only its header via `ImageIO`.
	public static func getImageDimensions(from localURL: URL) -> CGSize? {
		guard let imageSource = CGImageSourceCreateWithURL(localURL as CFURL, nil) else {
			return nil
		}

		guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
			return nil
		}

		guard let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
			  let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
			return nil
		}

		return CGSize(width: width, height: height)
	}

	/// Returns the pixel dimensions of a remote image by fetching only the first 2KB of bytes (an HTTP `Range` request), without a full download.
	public static func getImageDimensionsFromURL(from url: URL) async -> CGSize? {
		do {
			// Создаем URLRequest с заголовком для частичной загрузки
			var request = URLRequest(url: url)
			request.setValue("bytes=0-2048", forHTTPHeaderField: "Range") // Загружаем только первые 2KB

			let (data, _) = try await URLSession.shared.data(for: request)

			// Создаем CGImageSource из частичных данных
			guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
				return nil
			}

			// Получаем свойства изображения без декодирования
			guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
				return nil
			}

			// Извлекаем ширину и высоту
			guard let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
				  let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else {
				return nil
			}

			return CGSize(width: width, height: height)

		} catch {
			return nil
		}
	}

	/// Returns the height an image should have at `targetWidth` to preserve its original aspect ratio.
	public static func calculateHeight(for originalSize: CGSize, targetWidth: CGFloat) -> CGFloat {
		let aspectRatio = originalSize.height / originalSize.width
		return targetWidth * aspectRatio
	}
}
