import { common, Want } from '@kit.AbilityKit';
import { inputMethod } from '@kit.IMEKit';
import { router } from '@kit.ArkUI';
import { fileIo } from '@kit.CoreFileKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { i18n } from '@kit.LocalizationKit';
import { SettingsStore, VikeySettings } from '../model/SettingsStore';
import { CaseResult, EngineCases } from '../ime/EngineCases';

@Entry
@Component
struct Index {
  @State settings: VikeySettings = new VikeySettings();
  @State statusCode: number = 0;
  @State hint: string = '';
  @State cases: string = '';
  @State notice: string = '';
  private context: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    const host = this.getUIContext().getHostContext();
    if (host !== undefined) {
      this.context = host as common.UIAbilityContext;
      this.settings = SettingsStore.load(this.context);
      if (!this.settings.didOnboard) {
        router.replaceUrl({ url: 'pages/Onboarding' });
        return;
      }
      this.refreshStatus();
    }
  }

  build() {
    Scroll() {
      Column() {
        Text($r('app.string.app_name')).fontSize(28).fontWeight(FontWeight.Bold).width('100%')
          .fontColor($r('app.color.text')).margin({ top: 16, bottom: 8 })
        this.statusCard()
        Text($r('app.string.try_keyboard')).fontSize(16).fontWeight(FontWeight.Medium).width('100%')
          .fontColor($r('app.color.text')).margin({ top: 16 })
        TextArea({ placeholder: $r('app.string.try_placeholder') })
          .width('100%').height(96).margin({ top: 8 })
        TextInput({ placeholder: $r('app.string.password_placeholder') })
          .type(InputType.Password).width('100%').margin({ top: 8 })
        this.section($r('app.string.sec_auto'))
        this.toggle($r('app.string.auto_switch'), $r('app.string.auto_switch_tip'), this.settings.autoSwitch,
          (v: boolean) => { this.settings.autoSwitch = v; this.persist(); })
        this.toggle($r('app.string.pause'), $r('app.string.pause_tip'), this.settings.pause,
          (v: boolean) => { this.settings.pause = v; this.persist(); })
        this.toggle($r('app.string.web_english'), $r('app.string.web_english_tip'), this.settings.webEnglish,
          (v: boolean) => { this.settings.webEnglish = v; this.persist(); })
        this.section($r('app.string.sec_vietnamese'))
        Text($r('app.string.telex_style')).fontSize(16).width('100%').fontColor($r('app.color.text'))
        Text($r('app.string.telex_style_tip')).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
        Row() {
          this.choice($r('app.string.telex'), this.settings.telexStyle === 0, () => { this.settings.telexStyle = 0; this.persist(); })
          this.choice($r('app.string.telex_simple1'), this.settings.telexStyle === 1, () => { this.settings.telexStyle = 1; this.persist(); })
          this.choice($r('app.string.telex_simple2'), this.settings.telexStyle === 2, () => { this.settings.telexStyle = 2; this.persist(); })
        }.width('100%').margin({ top: 8 })
        this.toggle($r('app.string.tone_placement'), $r('app.string.tone_placement_tip'), this.settings.modern,
          (v: boolean) => { this.settings.modern = v; this.persist(); })
        this.toggle($r('app.string.spelling'), $r('app.string.spelling_tip'), this.settings.spelling,
          (v: boolean) => { this.settings.spelling = v; this.persist(); })
        this.toggle($r('app.string.restore'), $r('app.string.restore_tip'), this.settings.restore,
          (v: boolean) => { this.settings.restore = v; this.persist(); })
        this.section($r('app.string.sec_keyboard'))
        this.toggle($r('app.string.suggestions'), $r('app.string.suggestions_tip'), this.settings.suggestions,
          (v: boolean) => { this.settings.suggestions = v; this.persist(); })
        this.toggle($r('app.string.autocorrect'), $r('app.string.autocorrect_tip'), this.settings.autoCorrect,
          (v: boolean) => { this.settings.autoCorrect = v; this.persist(); })
        this.toggle($r('app.string.autocap'), $r('app.string.autocap_tip'), this.settings.autoCap,
          (v: boolean) => { this.settings.autoCap = v; this.persist(); })
        this.toggle($r('app.string.haptics'), $r('app.string.haptics_tip'), this.settings.haptics,
          (v: boolean) => { this.settings.haptics = v; this.persist(); })
        this.toggle($r('app.string.double_space'), $r('app.string.double_space_tip'), this.settings.doubleSpace,
          (v: boolean) => { this.settings.doubleSpace = v; this.persist(); })
        this.section($r('app.string.sec_debug'))
        this.toggle($r('app.string.diagnostics'), $r('app.string.diagnostics_tip'), this.settings.diagnostics,
          (v: boolean) => { this.settings.diagnostics = v; this.persist(); })
        Button($r('app.string.run_cases')).width('100%').margin({ top: 8 }).onClick(() => { this.runCases(); })
        if (this.cases.length > 0) {
          Text(this.cases).fontSize(12).width('100%').fontColor($r('app.color.text')).margin({ top: 8 })
        }
        Button($r('app.string.copy_log')).width('100%').margin({ top: 8 }).onClick(() => { this.copyLog(); })
        Button($r('app.string.clear_log')).width('100%').margin({ top: 8 }).onClick(() => { this.clearLog(); })
        if (this.notice.length > 0) {
          Text(this.notice).fontSize(13).width('100%').fontColor($r('app.color.accent')).margin({ top: 8 })
        }
        Button($r('app.string.app_language')).width('100%').margin({ top: 12 }).onClick(() => { this.switchLanguage(); })
        Button($r('app.string.review_onboarding')).width('100%').margin({ top: 8 }).onClick(() => {
          this.settings.didOnboard = false;
          this.persist();
          router.replaceUrl({ url: 'pages/Onboarding' });
        })
        Button($r('app.string.acknowledgements')).width('100%').margin({ top: 8 })
          .onClick(() => { router.pushUrl({ url: 'pages/Acknowledgements' }); })
        Text($r('app.string.version')).fontSize(13).fontColor($r('app.color.secondary')).margin({ top: 16 })
        this.creditLine()
      }
      .padding(16)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.page_bg'))
    .onAppear(() => { this.refreshStatus(); })
  }

  @Builder
  creditLine() {
    Text() {
      Span($r('app.string.footer_lead'))
      Span($r('app.string.footer_name'))
        .fontColor($r('app.color.accent'))
        .decoration({ type: TextDecorationType.Underline, color: $r('app.color.accent') })
        .onClick(() => { this.openDesigner(); })
      Span($r('app.string.footer_tail'))
    }
    .fontSize(13)
    .fontColor($r('app.color.secondary'))
    .width('100%')
    .margin({ top: 8, bottom: 24 })
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

  @Builder
  statusCard() {
    Column() {
      Text(this.statusCode === 2 ? $r('app.string.state_full') :
        this.statusCode === 1 ? $r('app.string.added') : $r('app.string.not_added'))
        .fontSize(16).fontWeight(FontWeight.Medium).fontColor($r('app.color.text')).width('100%')
      Text($r('app.string.add_keyboard_footer')).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
      if (this.hint.length > 0) {
        Text(this.hint).fontSize(13).fontColor($r('app.color.secondary')).width('100%').margin({ top: 6 })
      }
      Button($r('app.string.open_settings')).width('100%').margin({ top: 8 }).onClick(() => { this.openSettings(); })
      Button($r('app.string.select_keyboard')).width('100%').margin({ top: 8 }).onClick(() => { this.selectVikey(); })
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('app.color.card'))
    .borderRadius(12)
  }

  @Builder
  section(title: Resource) {
    Text(title).fontSize(13).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent'))
      .width('100%').margin({ top: 18, bottom: 6 })
  }

  @Builder
  toggle(title: Resource, tip: Resource, value: boolean, change: (next: boolean) => void) {
    Column() {
      Row() {
        Text(title).fontSize(16).fontColor($r('app.color.text')).layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: value }).onChange((on: boolean) => { change(on); })
      }.width('100%')
      Text(tip).fontSize(13).fontColor($r('app.color.secondary')).width('100%')
    }.width('100%').margin({ top: 8 })
  }

  @Builder
  choice(title: Resource, on: boolean, pick: () => void) {
    Text(title)
      .fontSize(13)
      .padding({ left: 8, right: 8, top: 6, bottom: 6 })
      .margin({ right: 6 })
      .borderRadius(8)
      .backgroundColor(on ? $r('app.color.accent') : $r('app.color.card'))
      .fontColor(on ? Color.White : $r('app.color.text'))
      .onClick(() => { pick(); })
  }

  private persist(): void {
    if (this.context !== null) {
      SettingsStore.save(this.context, this.settings);
    }
  }

  private refreshStatus(): void {
    inputMethod.getSetting().getInputMethodState().then((state: inputMethod.EnabledState) => {
      if (state === inputMethod.EnabledState.DISABLED) {
        this.statusCode = 0;
      } else if (state === inputMethod.EnabledState.FULL_EXPERIENCE_MODE) {
        this.statusCode = 2;
      } else {
        this.statusCode = 1;
      }
    }).catch(() => {
      this.statusCode = 0;
    });
  }

  private textOf(resource: Resource): string {
    if (this.context === null) {
      return '';
    }
    try {
      return this.context.resourceManager.getStringSync(resource.id);
    } catch (_e) {
      return '';
    }
  }

  private openSettings(): void {
    if (this.context === null) {
      return;
    }
    const wants: Want[] = [
      { bundleName: 'com.huawei.hmos.settings', abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'input_method_settings' },
      { bundleName: 'com.huawei.hmos.settings', abilityName: 'com.huawei.hmos.settings.MainAbility' },
      { action: 'ohos.settings.inputmethod.settings' }
    ];
    this.tryWant(wants, 0);
  }

  private tryWant(wants: Want[], index: number): void {
    if (this.context === null || index >= wants.length) {
      this.hint = this.textOf($r('app.string.settings_path'));
      return;
    }
    this.context.startAbility(wants[index]).then(() => {
      this.hint = '';
    }).catch(() => {
      this.tryWant(wants, index + 1);
    });
  }

  private selectVikey(): void {
    try {
      const list = inputMethod.getSetting().getInputMethodsSync(true);
      for (let i = 0; i < list.length; i++) {
        if (list[i].name === 'app.vikey.harmony' || list[i].id === 'InputMethodService') {
          inputMethod.switchInputMethod(list[i]);
          this.notice = this.textOf($r('app.string.added'));
          return;
        }
      }
      this.hint = this.textOf($r('app.string.settings_path'));
    } catch (_e) {
      this.hint = this.textOf($r('app.string.settings_path'));
    }
  }

  private runCases(): void {
    const results = EngineCases.run();
    let passed = 0;
    let text = '';
    for (let i = 0; i < results.length; i++) {
      const item: CaseResult = results[i];
      if (item.ok) {
        passed++;
      }
      text += (item.ok ? 'ok  ' : 'FAIL ') + item.name;
      if (!item.ok) {
        text += ' got=' + item.got;
      }
      text += '\n';
    }
    this.cases = passed + '/' + results.length + '\n' + text;
  }

  private logPath(): string {
    if (this.context === null) {
      return '';
    }
    return this.context.filesDir + '/keyboard-log.txt';
  }

  private copyLog(): void {
    const path = this.logPath();
    let text = '';
    try {
      text = fileIo.readTextSync(path);
    } catch (_e) {
      text = '';
    }
    if (text.length === 0) {
      this.notice = this.textOf($r('app.string.log_empty'));
      return;
    }
    const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    pasteboard.getSystemPasteboard().setData(data);
    this.notice = this.textOf($r('app.string.log_copied'));
  }

  private clearLog(): void {
    try {
      fileIo.truncateSync(this.logPath(), 0);
    } catch (_e) {
    }
    this.notice = this.textOf($r('app.string.log_empty'));
  }

  private switchLanguage(): void {
    let next = 'en-US';
    try {
      const current = i18n.System.getAppPreferredLanguage();
      if (current.startsWith('en')) {
        next = 'zh-CN';
      } else if (current.startsWith('zh')) {
        next = 'vi-VN';
      }
    } catch (_e) {
    }
    this.applyLanguage(next);
  }

  private applyLanguage(next: string): void {
    try {
      i18n.System.setAppPreferredLanguage(next);
    } catch (_e) {
      this.notice = next;
    }
  }
}
