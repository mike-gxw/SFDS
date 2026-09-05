// Index.ets - 主界面（频域水印工具）

import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { promptAction, router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { abilityAccessCtrl } from '@kit.AbilityKit';
import { LoadedImage, selectImage, loadImagePixels } from '../common/ImageHelper';
import { textToBits, bitsToText } from '../common/WatermarkUtils';
import { embedWatermarkAsync, extractWatermarkAsync, maxBitsCapacity } from '../common/DctWatermark';
import { PrivacyDialog } from '../common/PrivacyDialog';

// 色板常量（霜雾水色 + 液态玻璃主题）
const COL_BG_1: string = '#D8ECF8';
const COL_BG_2: string = '#D3EFF1';
const COL_BG_3: string = '#DCF3E9';
const COL_BG_4: string = '#F2F0E9';
const COL_CARD: string = 'rgba(255,255,255,0.55)';
const COL_TEXT: string = '#1E2A3B';
const COL_TEXT_SUB: string = '#5A6B7F';
const COL_TEXT_DIM: string = '#8C99A9';
const COL_PRIMARY: string = '#33B5E8';
const COL_PRIMARY_2: string = '#5A6CF0';
const COL_INPUT_BG: string = 'rgba(255,255,255,0.60)';

// 手写 32 位 BMP 编码（RGBA -> BGRA，bottom-up）
function encodeBmp(pixels: Uint8Array, width: number, height: number): Uint8Array {
  const rowSize: number = width * 4;
  const pixelDataSize: number = rowSize * height;
  const fileSize: number = 54 + pixelDataSize;
  const bmp: Uint8Array = new Uint8Array(fileSize);
  const view: DataView = new DataView(bmp.buffer);
  view.setUint8(0, 0x42);
  view.setUint8(1, 0x4D);
  view.setUint32(2, fileSize, true);
  view.setUint16(6, 0, true);
  view.setUint16(8, 0, true);
  view.setUint32(10, 54, true);
  view.setUint32(14, 40, true);
  view.setInt32(18, width, true);
  view.setInt32(22, height, true);
  view.setUint16(26, 1, true);
  view.setUint16(28, 32, true);
  view.setUint32(30, 0, true);
  view.setUint32(34, pixelDataSize, true);
  view.setInt32(38, 2835, true);
  view.setInt32(42, 2835, true);
  view.setUint32(46, 0, true);
  view.setUint32(50, 0, true);
  for (let y: number = 0; y < height; y++) {
    const srcRow: number = height - 1 - y;
    for (let x: number = 0; x < width; x++) {
      const srcIdx: number = (srcRow * width + x) * 4;
      const dstIdx: number = 54 + y * rowSize + x * 4;
      bmp[dstIdx] = pixels[srcIdx + 2];
      bmp[dstIdx + 1] = pixels[srcIdx + 1];
      bmp[dstIdx + 2] = pixels[srcIdx];
      bmp[dstIdx + 3] = pixels[srcIdx + 3];
    }
  }
  return bmp;
}

@Entry
@Component
struct Index {
  @State previewUri: string = '';
  @State resultUri: string = '';
  @State watermarkText: string = '';
  @State statusText: string = '未选择图片';
  @State resultText: string = '';
  @State isBusy: boolean = false;
  @State hasResult: boolean = false;
  private currentImage: LoadedImage | null = null;
  private resultPixels: Uint8Array | null = null;
  private resultWidth: number = 0;
  private resultHeight: number = 0;
  private privacyController: CustomDialogController | null = null;

  aboutToAppear(): void {
    this.privacyController = new CustomDialogController({
      builder: PrivacyDialog({
        onAgree: (): void => {
          this.onPrivacyAgree();
        },
        onDisagree: (): void => {
          this.onPrivacyDisagree();
        }
      }),
      autoCancel: false
    });
    this.checkAndShowPrivacy();
  }

  private async checkAndShowPrivacy(): Promise<void> {
    const agreed: boolean = await this.readPrivacyAgreed();
    if (!agreed && this.privacyController !== null) {
      this.privacyController.open();
    }
  }

  private async readPrivacyAgreed(): Promise<boolean> {
    try {
      const context: Context = getContext(this);
      const pref: preferences.Preferences = await preferences.getPreferences(context, 'privacy_config');
      const val: preferences.ValueType = await pref.get('agreed', false);
      return val as boolean;
    } catch (e) {
      return false;
    }
  }

  private onPrivacyAgree(): void {
    this.savePrivacyAgreed();
  }

  private onPrivacyDisagree(): void {
    promptAction.showToast({ message: '需同意隐私政策后才能正常使用' });
  }

  private async savePrivacyAgreed(): Promise<void> {
    try {
      const context: Context = getContext(this);
      const pref: preferences.Preferences = await preferences.getPreferences(context, 'privacy_config');
      await pref.put('agreed', true);
      await pref.flush();
    } catch (e) {
      // 持久化失败不阻断使用
    }
  }

  private async onSelectImage(): Promise<void> {
    const uri: string = await selectImage();
    if (uri === '') {
      return;
    }
    this.isBusy = true;
    this.statusText = '加载中...';
    const img: LoadedImage | null = await loadImagePixels(uri);
    this.isBusy = false;
    if (img === null) {
      this.statusText = '图片加载失败';
      return;
    }
    this.currentImage = img;
    this.previewUri = uri;
    this.hasResult = false;
    this.resultUri = '';
    this.resultText = '';
    this.statusText = '已加载 ' + img.width + '×' + img.height + ' 图片';
  }

  private async onEmbedClick(): Promise<void> {
    if (this.currentImage === null) {
      promptAction.showToast({ message: '请先选择图片' });
      return;
    }
    if (this.watermarkText.length === 0) {
      promptAction.showToast({ message: '请输入水印文本' });
      return;
    }
    const bits: number[] = textToBits(this.watermarkText);
    const capacity: number = maxBitsCapacity(this.currentImage.width, this.currentImage.height);
    if (bits.length > capacity) {
      const maxChars: number = Math.floor((capacity - 16) / 16);
      promptAction.showToast({ message: '水印过长，最多 ' + maxChars + ' 字' });
      return;
    }
    this.isBusy = true;
    this.statusText = '嵌入中...';
    const w: number = this.currentImage.width;
    const h: number = this.currentImage.height;
    const pixels: Uint8Array = new Uint8Array(this.currentImage.pixels.length);
    pixels.set(this.currentImage.pixels);
    await embedWatermarkAsync(pixels, w, h, bits);
    this.resultPixels = pixels;
    this.resultWidth = w;
    this.resultHeight = h;
    this.currentImage.pixels = pixels;
    this.writeResultPreview(pixels, w, h);
    this.hasResult = true;
    this.resultText = '嵌入成功';
    this.statusText = '水印已嵌入，可保存到相册';
    this.isBusy = false;
  }

  private async writeResultPreview(pixels: Uint8Array, width: number, height: number): Promise<void> {
    const bmp: Uint8Array = encodeBmp(pixels, width, height);
    const context: Context = getContext(this);
    const path: string = context.cacheDir + '/result_' + Date.now() + '.bmp';
    const file: fileIo.File = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(file.fd, bmp.buffer);
    fileIo.closeSync(file);
    this.resultUri = fileUri.getUriFromPath(path);
  }

  private async onExtractClick(): Promise<void> {
    if (this.currentImage === null) {
      promptAction.showToast({ message: '请先选择图片' });
      return;
    }
    this.isBusy = true;
    this.statusText = '提取中...';
    const w: number = this.currentImage.width;
    const h: number = this.currentImage.height;
    const head: number[] = await extractWatermarkAsync(this.currentImage.pixels, w, h, 16);
    let len: number = 0;
    for (let i: number = 0; i < 16; i++) {
      len = (len << 1) | (head[i] & 1);
    }
    if (len <= 0 || len > 2000) {
      this.isBusy = false;
      this.resultText = '未检测到水印';
      this.statusText = '提取完成';
      return;
    }
    const needBlocks: number = 16 + len * 16;
    const bits: number[] = await extractWatermarkAsync(this.currentImage.pixels, w, h, needBlocks);
    const text: string = bitsToText(bits);
    this.isBusy = false;
    if (text.length === 0) {
      this.resultText = '未检测到水印';
      this.statusText = '提取完成';
    } else {
      this.resultText = text;
      this.statusText = '水印提取成功';
    }
  }

  private async onSaveClick(): Promise<void> {
    if (!this.hasResult || this.resultPixels === null) {
      promptAction.showToast({ message: '请先嵌入水印' });
      return;
    }
    const granted: boolean = await this.ensureWritePermission();
    if (!granted) {
      promptAction.showToast({ message: '需要相册权限才能保存' });
      this.statusText = '未授权相册权限';
      return;
    }
    this.isBusy = true;
    this.statusText = '保存中...';
    try {
      await this.saveToGallery(this.resultPixels, this.resultWidth, this.resultHeight);
      promptAction.showToast({ message: '已保存到相册' });
      this.statusText = '已保存到相册';
    } catch (e) {
      const msg: string = (e as Error).message !== undefined ? (e as Error).message : String(e);
      console.error('onSaveClick failed: ' + msg);
      promptAction.showToast({ message: '保存失败: ' + msg });
      this.statusText = '保存失败';
    }
    this.isBusy = false;
  }

  private async ensureWritePermission(): Promise<boolean> {
    try {
      const atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
      const context: Context = getContext(this);
      const tokenId: number = context.applicationInfo.accessTokenId;
      const gs: abilityAccessCtrl.GrantStatus = await atManager.checkAccessToken(tokenId, 'ohos.permission.WRITE_IMAGEVIDEO');
      if (gs === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
      const result = await atManager.requestPermissionsFromUser(context, ['ohos.permission.WRITE_IMAGEVIDEO']);
      return result.authResults.length > 0 && result.authResults[0] === 0;
    } catch (e) {
      return false;
    }
  }

  private async saveToGallery(pixels: Uint8Array, width: number, height: number): Promise<void> {
    const context: Context = getContext(this);
    const bmp: Uint8Array = encodeBmp(pixels, width, height);
    const tmpPath: string = context.cacheDir + '/save_' + Date.now() + '.bmp';
    const tmpFile: fileIo.File = fileIo.openSync(tmpPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(tmpFile.fd, bmp.buffer);
    fileIo.closeSync(tmpFile);
    const readFile: fileIo.File = fileIo.openSync(tmpPath, fileIo.OpenMode.READ_ONLY);
    const imageSource: image.ImageSource = image.createImageSource(readFile.fd);
    const pixelMap: image.PixelMap = await imageSource.createPixelMap({
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    const packer: image.ImagePacker = image.createImagePacker();
    const pngBuffer: ArrayBuffer = await packer.packing(pixelMap, { format: 'image/png', quality: 100 });
    packer.release();
    pixelMap.release();
    imageSource.release();
    fileIo.closeSync(readFile);
    const phAccessHelper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(context);
    const uri: string = await phAccessHelper.createAsset(photoAccessHelper.PhotoType.IMAGE, 'png');
    const outFile: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.WRITE_ONLY);
    fileIo.writeSync(outFile.fd, pngBuffer);
    fileIo.closeSync(outFile);
  }

  @Builder
  HeaderBar() {
    Row() {
      Text('频域水印工具-SFDS')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(COL_TEXT)
      Blank()
      Text('关于')
        .fontSize(14)
        .fontColor(COL_PRIMARY)
        .padding(8)
        .onClick(() => {
          router.pushUrl({ url: 'pages/About' });
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }

  @Builder
  PreviewArea() {
    Column() {
      if (this.resultUri !== '') {
        Image(this.resultUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else if (this.previewUri !== '') {
        Image(this.previewUri)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else {
        Column() {
          Text('点击选择图片')
            .fontSize(15)
            .fontColor(COL_TEXT_SUB)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .onClick(() => {
          this.onSelectImage();
        })
      }
    }
    .width('92%')
    .height(240)
    .backgroundColor(COL_CARD)
    .backgroundBlurStyle(BlurStyle.Regular)
    .borderRadius(16)
    .shadow({
      radius: 16,
      color: 'rgba(90,150,220,0.35)',
      offsetX: 0,
      offsetY: 4
    })
    .clip(true)
    .margin({ top: 8 })
  }

  @Builder
  InputArea() {
    Column() {
      Text('水印文本')
        .fontSize(14)
        .fontColor(COL_TEXT_SUB)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })
      TextInput({ text: this.watermarkText, placeholder: '请输入要嵌入的水印文字' })
        .fontSize(15)
        .fontColor(COL_TEXT)
        .placeholderColor(COL_TEXT_DIM)
        .backgroundColor(COL_INPUT_BG)
        .borderRadius(12)
        .height(44)
        .onChange((value: string) => {
          this.watermarkText = value;
        })
    }
    .width('92%')
    .margin({ top: 16 })
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ButtonArea() {
    Column() {
      Button('选择图片')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COL_TEXT)
        .backgroundColor(Color.Transparent)
        .height(52)
        .width('100%')
        .shadow({
          radius: 28,
          color: 'rgba(15,23,42,0.45)',
          offsetX: 0,
          offsetY: 10
        })
        .enabled(!this.isBusy)
        .onClick(() => {
          this.onSelectImage();
        })

      Row() {
        Button('嵌入水印')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COL_TEXT)
          .backgroundColor(Color.Transparent)
          .height(52)
          .layoutWeight(1)
          .shadow({
            radius: 28,
            color: 'rgba(15,23,42,0.45)',
            offsetX: 0,
            offsetY: 10
          })
          .enabled(!this.isBusy)
          .onClick(() => {
            this.onEmbedClick();
          })

        Button('提取水印')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COL_TEXT)
          .backgroundColor(Color.Transparent)
          .height(52)
          .layoutWeight(1)
          .margin({ left: 16 })
          .shadow({
            radius: 28,
            color: 'rgba(15,23,42,0.45)',
            offsetX: 0,
            offsetY: 10
          })
          .enabled(!this.isBusy)
          .onClick(() => {
            this.onExtractClick();
          })
      }
      .width('100%')
      .margin({ top: 24 })

      Button('保存到相册')
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(COL_TEXT)
        .backgroundColor(Color.Transparent)
        .height(52)
        .width('100%')
        .margin({ top: 24 })
        .shadow({
          radius: 28,
          color: 'rgba(15,23,42,0.45)',
          offsetX: 0,
          offsetY: 10
        })
        .enabled(this.hasResult && !this.isBusy)
        .onClick(() => {
          this.onSaveClick();
        })
    }
    .width('92%')
    .margin({ top: 28 })
  }

  @Builder
  ResultArea() {
    Column() {
      Text('结果')
        .fontSize(14)
        .fontColor(COL_TEXT_SUB)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })
      Column() {
        Text(this.resultText === '' ? '暂无结果' : this.resultText)
          .fontSize(15)
          .fontColor(this.resultText === '' ? COL_TEXT_DIM : COL_TEXT)
          .width('100%')
          .padding(12)
      }
      .width('100%')
      .backgroundColor(COL_CARD)
      .backgroundBlurStyle(BlurStyle.Regular)
      .borderRadius(12)
      .shadow({
        radius: 12,
        color: 'rgba(90,150,220,0.30)',
        offsetX: 0,
        offsetY: 3
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('92%')
    .margin({ top: 20 })
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Column() {
      this.HeaderBar()
      Scroll() {
        Column() {
          this.PreviewArea()
          Text(this.statusText)
            .fontSize(12)
            .fontColor(COL_TEXT_DIM)
            .width('92%')
            .margin({ top: 8 })
          this.InputArea()
          this.ButtonArea()
          this.ResultArea()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)

      Text('本地处理 · 数据不上传 · 隐私安全')
        .fontSize(11)
        .fontColor(COL_TEXT_DIM)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 12 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 135, colors: [[COL_BG_1, 0.0], [COL_BG_2, 0.33], [COL_BG_3, 0.66], [COL_BG_4, 1.0]] })
  }
}
