import { common, Want } from '@kit.AbilityKit';
import { router } from '@kit.ArkUI';

@Entry
@Component
struct Acknowledgements {
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    const host = this.getUIContext().getHostContext();
    if (host !== undefined) {
      this.context = host as common.UIAbilityContext;
    }
  }

  build() {
    Scroll() {
      Column() {
        Text($r('app.string.acknowledgements')).fontSize(28).fontWeight(FontWeight.Bold).width('100%')
          .fontColor($r('app.color.text'))
        Text($r('app.string.ack_code')).fontSize(18).fontWeight(FontWeight.Medium).width('100%')
          .margin({ top: 16 }).fontColor($r('app.color.text'))
        Text($r('app.string.ack_code_note')).fontSize(15).width('100%').fontColor($r('app.color.secondary'))
        Text($r('app.string.ack_words')).fontSize(18).fontWeight(FontWeight.Medium).width('100%')
          .margin({ top: 16 }).fontColor($r('app.color.text'))
        Text($r('app.string.ack_words_note')).fontSize(15).width('100%').fontColor($r('app.color.secondary'))
        Text($r('app.string.ack_license')).fontSize(18).fontWeight(FontWeight.Medium).width('100%')
          .margin({ top: 16 }).fontColor($r('app.color.text'))
        Text($r('app.string.ack_license_note')).fontSize(15).width('100%').fontColor($r('app.color.secondary'))
        Text() {
          Span($r('app.string.footer_lead'))
          Span($r('app.string.footer_name'))
            .fontColor($r('app.color.accent'))
            .decoration({ type: TextDecorationType.Underline, color: $r('app.color.accent') })
            .onClick(() => { this.openDesigner(); })
          Span($r('app.string.footer_tail'))
        }
        .fontSize(14)
        .fontColor($r('app.color.secondary'))
        .width('100%')
        .margin({ top: 20 })
        Button($r('app.string.onb_done')).width('100%').margin({ top: 20 }).onClick(() => { router.back(); })
      }.padding(20).width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
  }

  private openDesigner(): void {
    if (this.context === null) {
      return;
    }
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: 'https://www.facebook.com/nnguyenthemanh'
    };
    this.context.startAbility(want).catch(() => {
    });
  }
}
