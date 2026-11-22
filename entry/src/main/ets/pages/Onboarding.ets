import { common, Want } from '@kit.AbilityKit';
import { inputMethod } from '@kit.IMEKit';
import { router } from '@kit.ArkUI';
import { SettingsStore, VikeySettings } from '../model/SettingsStore';

@Entry
@Component
struct Onboarding {
  @State step: number = 0;
  @State imeOn: boolean = false;
  @State hint: string = '';
  private context: common.UIAbilityContext | null = null;
  private settings: VikeySettings = new VikeySettings();

  aboutToAppear(): void {
    const host = this.getUIContext().getHostContext();
    if (host !== undefined) {
      this.context = host as common.UIAbilityContext;
      this.settings = SettingsStore.load(this.context);
      this.refresh();
    }
  }

  build() {
    Column() {
      Text(this.step === 0 ? $r('app.string.onb_title1') : this.step === 1 ? $r('app.string.onb_title2') :
        $r('app.string.onb_title3'))
        .fontSize(26).fontWeight(FontWeight.Bold).width('100%').fontColor($r('app.color.text'))
      if (this.step === 0) {
        Text($r('app.string.onb_sub1')).fontSize(16).fontColor($r('app.color.secondary')).width('100%').margin({ top: 12 })
        Text($r('app.string.onb_privacy')).fontSize(14).fontColor($r('app.color.secondary')).width('100%').margin({ top: 12 })
      } else if (this.step === 1) {
        Text($r('app.string.onb_step1')).fontSize(16).width('100%').margin({ top: 12 }).fontColor($r('app.color.text'))
        Text($r('app.string.onb_step2')).fontSize(16).width('100%').margin({ top: 8 }).fontColor($r('app.color.text'))
        Text($r('app.string.onb_step3')).fontSize(16).width('100%').margin({ top: 8 }).fontColor($r('app.color.text'))
        Text(this.imeOn ? $r('app.string.added') : $r('app.string.not_added'))
          .fontSize(16).fontWeight(FontWeight.Medium).margin({ top: 16 }).fontColor($r('app.color.accent'))
        Button($r('app.string.open_settings')).width('100%').margin({ top: 12 }).onClick(() => { this.openSettings(); })
        if (this.hint.length > 0) {
          Text(this.hint).fontSize(13).width('100%').margin({ top: 8 }).fontColor($r('app.color.secondary'))
        }
      } else {
        Text($r('app.string.onb_sub3')).fontSize(16).width('100%').margin({ top: 12 }).fontColor($r('app.color.secondary'))
        TextArea({ placeholder: $r('app.string.onb_type_here') }).width('100%').height(120).margin({ top: 12 })
      }
      Blank()
      Button(this.step === 0 ? $r('app.string.onb_start') : this.step === 1 ? $r('app.string.onb_continue') :
        $r('app.string.onb_done'))
        .width('100%')
        .onClick(() => { this.next(); })
    }
    .padding(20)
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onAppear(() => { this.refresh(); })
  }

  private next(): void {
    if (this.step < 2) {
      this.step++;
      this.refresh();
      return;
    }
    this.settings.didOnboard = true;
    if (this.context !== null) {
      SettingsStore.save(this.context, this.settings);
    }
    router.replaceUrl({ url: 'pages/Index' });
  }

  private refresh(): void {
    inputMethod.getSetting().getInputMethodState().then((state: inputMethod.EnabledState) => {
      this.imeOn = state !== inputMethod.EnabledState.DISABLED;
    }).catch(() => {
      this.imeOn = false;
    });
  }

  private openSettings(): void {
    if (this.context === null) {
      return;
    }
    const wants: Want[] = [
      { bundleName: 'com.huawei.hmos.settings', abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'input_method_settings' },
      { bundleName: 'com.huawei.hmos.settings', abilityName: 'com.huawei.hmos.settings.MainAbility' }
    ];
    this.context.startAbility(wants[0]).catch(() => {
      if (this.context !== null) {
        this.context.startAbility(wants[1]).catch(() => {
          this.hint = 'Settings › System › Keyboard & input method';
        });
      }
    });
  }
}
