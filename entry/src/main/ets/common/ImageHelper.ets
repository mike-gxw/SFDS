// ImageHelper.ets - 图片选择与加载辅助

import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';

// 已加载图片（RGBA 像素 + 尺寸）
export class LoadedImage {
  pixels: Uint8Array;
  width: number;
  height: number;

  constructor(pixels: Uint8Array, width: number, height: number) {
    this.pixels = pixels;
    this.width = width;
    this.height = height;
  }
}

// 选图，返回图片 URI（空串表示用户取消）
export async function selectImage(): Promise<string> {
  const photoPicker = new photoAccessHelper.PhotoViewPicker();
  const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select({
    MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
    maxSelectNumber: 1
  });
  if (result.photoUris.length > 0) {
    return result.photoUris[0];
  }
  return '';
}

// 加载图片为 RGBA 像素（显式指定 RGBA_8888，避免 JPEG 解码为 RGB_888 导致越界）
export async function loadImagePixels(uri: string): Promise<LoadedImage | null> {
  const file: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
  const imageSource: image.ImageSource = image.createImageSource(file.fd);
  const pixelMap: image.PixelMap = await imageSource.createPixelMap({
    desiredPixelFormat: image.PixelMapFormat.RGBA_8888
  });
  const imageInfo: image.ImageInfo = await pixelMap.getImageInfo();
  const width: number = imageInfo.size.width;
  const height: number = imageInfo.size.height;
  const buffer: ArrayBuffer = new ArrayBuffer(width * height * 4);
  await pixelMap.readPixelsToBuffer(buffer);
  const pixels: Uint8Array = new Uint8Array(buffer);
  pixelMap.release();
  imageSource.release();
  fileIo.closeSync(file);
  return new LoadedImage(pixels, width, height);
}
