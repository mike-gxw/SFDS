import { router } from '@kit.ArkUI';

@Entry
@Component
struct About {
  build() {
    Column() {
      Row() {
        Text('< 返回')
          .fontSize(16)
          .fontColor('#33B5E8')
          .padding(8)
          .onClick(() => {
            router.back();
          })

        Blank()

        Text('关于')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E2A3B')

        Blank()
        Row().width(60)
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 12, bottom: 12 })

      Column() {
        Row() {
          Text('SFDS')
            .fontSize(52)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1E2A3B')
        }
        .width('70%')
        .height(130)
        .borderRadius(32)
        .backgroundColor(Color.Transparent)
        .justifyContent(FlexAlign.Center)
        .shadow({
          radius: 28,
          color: 'rgba(15,23,42,0.45)',
          offsetX: 0,
          offsetY: 10
        })
        .margin({ top: 72 })

        Text('频域水印')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1E2A3B')
          .margin({ top: 20 })

        Text('版本 1.0.0')
          .fontSize(14)
          .fontColor('#5A6B7F')
          .margin({ top: 8 })

        Column() {
          Text('技术说明')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1E2A3B')
            .alignSelf(ItemAlign.Start)

          Text('本应用基于离散余弦变换（DCT）实现频域数字水印算法，支持文本水印的嵌入与提取。适用于版权保护与信息隐藏场景。')
            .fontSize(14)
            .fontColor('#5A6B7F')
            .margin({ top: 10 })
            .lineHeight(22)
            .alignSelf(ItemAlign.Start)
        }
        .width('86%')
        .padding(16)
        .backgroundColor('rgba(255,255,255,0.55)')
        .backgroundBlurStyle(BlurStyle.Regular)
        .borderRadius(16)
        .shadow({
          radius: 16,
          color: 'rgba(90,150,220,0.35)',
          offsetX: 0,
          offsetY: 4
        })
        .margin({ top: 28 })

        Text('隐私政策')
          .fontSize(14)
          .fontColor('#33B5E8')
          .margin({ top: 24 })
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Text('© 2026 频域水印 · 本地处理，数据不上传')
        .fontSize(11)
        .fontColor('#8C99A9')
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .linearGradient({ angle: 135, colors: [['#D8ECF8', 0.0], ['#D3EFF1', 0.33], ['#DCF3E9', 0.66], ['#F2F0E9', 1.0]] })
  }
}
