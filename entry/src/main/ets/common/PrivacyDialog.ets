// PrivacyDialog.ets - 隐私政策弹窗

@CustomDialog
export struct PrivacyDialog {
  controller: CustomDialogController;
  onAgree?: () => void;
  onDisagree?: () => void;

  build() {
    Column() {
      Text($r('app.string.privacy_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .margin({ bottom: 16 })

      Scroll() {
        Text($r('app.string.privacy_content'))
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .lineHeight(22)
      }
      .height(200)
      .margin({ bottom: 24 })

      Row() {
        Button($r('app.string.disagree'))
          .fontSize(16)
          .backgroundColor($r('app.color.input_bg'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => {
            if (this.onDisagree) {
              this.onDisagree();
            }
            this.controller.close();
          })

        Button($r('app.string.agree'))
          .fontSize(16)
          .backgroundColor($r('app.color.primary'))
          .fontColor($r('app.color.white'))
          .margin({ left: 16 })
          .onClick(() => {
            if (this.onAgree) {
              this.onAgree();
            }
            this.controller.close();
          })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .padding(24)
    .width('80%')
    .borderRadius(16)
    .backgroundColor('rgba(255,255,255,0.55)')
    .backgroundBlurStyle(BlurStyle.Regular)
    .shadow({
      radius: 18,
      color: 'rgba(90,150,220,0.35)',
      offsetX: 0,
      offsetY: 6
    })
  }
}
