import { ConfigurationConstant } from '@kit.AbilityKit';
import { display, window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { inputMethod, inputMethodEngine, InputMethodExtensionContext } from '@kit.IMEKit';
import { KeyCode } from '@kit.InputKit';
import { fileIo } from '@kit.CoreFileKit';
import { SettingsStore, VikeySettings } from '../../model/SettingsStore';
import { typingSession, TextTarget } from '../../ime/TypingSession';
import { KeyLayout } from '../../ime/KeyLayout';
import { emojiModel } from '../../ime/EmojiModel';
import { nextWords } from '../../ime/NextWords';

class ClientTarget implements TextTarget {
  client: inputMethodEngine.InputClient | null = null;

  insert(text: string): void {
    this.client?.insertTextSync(text);
  }

  deleteBack(count: number): void {
    if (this.client === null || count < 1) {
      return;
    }
    try {
      this.client.deleteForwardSync(count);
    } catch (_e) {
    }
  }

  sendAction(action: number): void {
    this.client?.sendKeyFunction(action);
  }

  moveLeft(steps: number): void {
    for (let i = 0; i < steps; i++) {
      this.client?.moveCursorSync(inputMethodEngine.Direction.CURSOR_LEFT);
    }
  }

  moveRight(steps: number): void {
    for (let i = 0; i < steps; i++) {
      this.client?.moveCursorSync(inputMethodEngine.Direction.CURSOR_RIGHT);
    }
  }

  readBefore(max: number): string {
    if (this.client === null) {
      return '';
    }
    return this.client.getForwardSync(max);
  }

  readAfter(max: number): string {
    if (this.client === null) {
      return '';
    }
    return this.client.getBackwardSync(max);
  }
}

/** Input method lifecycle: one fixed soft-keyboard panel, one engine session. */
export class KeyboardController {
  private context: InputMethodExtensionContext | null = null;
  private panel: inputMethodEngine.Panel | null = null;
  private creating: boolean = false;
  private ability: inputMethodEngine.InputMethodAbility | null = null;
  private kb: inputMethodEngine.KeyboardController | null = null;
  private target: ClientTarget = new ClientTarget();
  private shiftDown: boolean = false;
  private capsLock: boolean = false;
  private settings: VikeySettings = new VikeySettings();
  private searchPanel: boolean = false;
  imes: inputMethod.InputMethodProperty[] = [];

  onCreate(context: InputMethodExtensionContext): void {
    this.context = context;
    AppStorage.setOrCreate('kbTick', 0);
    AppStorage.setOrCreate('imeMenu', false);
    AppStorage.setOrCreate('kbDark', false);
    this.followSystem();
    this.ability = inputMethodEngine.getInputMethodAbility();
    const app = context.getApplicationContext();
    this.reloadSettings();
    typingSession.persistLanguage = (language: number): void => {
      this.settings.language = language;
      if (this.context !== null) {
        SettingsStore.save(this.context.getApplicationContext(), this.settings);
      }
    };
    typingSession.changed = (): void => {
      const tick = AppStorage.get<number>('kbTick') ?? 0;
      AppStorage.setOrCreate('kbTick', tick + 1);
    };
    emojiModel.bind(app, this.settings);
    nextWords.bind(app);
    emojiModel.setUsage(this.settings.emojiUsage);
    this.register();
    this.ensurePanel();
  }

  onDestroy(): void {
    typingSession.detach();
    typingSession.driver.close();
    if (this.panel !== null && this.ability !== null) {
      this.ability.destroyPanel(this.panel);
      this.panel = null;
    }
  }

  reloadSettings(): void {
    if (this.context === null) {
      return;
    }
    this.settings = SettingsStore.load(this.context.getApplicationContext());
    typingSession.reload(this.settings);
    emojiModel.tone = this.settings.emojiTone;
    emojiModel.setUsage(this.settings.emojiUsage);
    this.refreshGlobe();
  }

  switchNext(): void {
    this.refreshGlobe();
    if (this.imes.length < 2) {
      return;
    }
    const current = inputMethod.getCurrentInputMethod();
    let index = 0;
    for (let i = 0; i < this.imes.length; i++) {
      if (this.imes[i].id === current.id && this.imes[i].name === current.name) {
        index = i;
      }
    }
    inputMethod.switchInputMethod(this.imes[(index + 1) % this.imes.length]);
  }

  showMenu(): void {
    this.refreshGlobe();
    AppStorage.setOrCreate('imeMenu', true);
    typingSession.changed?.();
  }

  pickIme(index: number): void {
    AppStorage.setOrCreate('imeMenu', false);
    if (index >= 0 && index < this.imes.length) {
      inputMethod.switchInputMethod(this.imes[index]);
    }
  }

  hideMenu(): void {
    AppStorage.setOrCreate('imeMenu', false);
  }

  imeNames(): string[] {
    const names: string[] = [];
    for (let i = 0; i < this.imes.length; i++) {
      const label = this.imes[i].label;
      names.push(label !== undefined && label.length > 0 ? label : this.imes[i].name);
    }
    return names;
  }

  private refreshGlobe(): void {
    try {
      this.imes = inputMethod.getSetting().getInputMethodsSync(true);
    } catch (_e) {
      this.imes = [];
    }
    typingSession.showsGlobe = this.imes.length > 1;
  }

  private register(): void {
    const ability = this.ability;
    if (ability === null) {
      return;
    }
    ability.on('inputStart', (kbController: inputMethodEngine.KeyboardController,
      inputClient: inputMethodEngine.InputClient) => {
      this.target.client = inputClient;
      this.reloadSettings();
      let pattern = inputMethod.TextInputType.TEXT;
      let enter = inputMethod.EnterKeyType.UNSPECIFIED;
      try {
        const attr = inputClient.getEditorAttributeSync();
        pattern = attr.inputPattern;
        enter = attr.enterKeyType;
      } catch (_e) {
      }
      let secure = false;
      try {
        secure = ability.getSecurityMode() === inputMethodEngine.SecurityMode.FULL ? false : false;
      } catch (_e) {
      }
      typingSession.attach(this.target, pattern, enter, this.passwordPattern(pattern) || secure);
      this.syncChrome();
      this.resize();
      this.kb = kbController;
    });
    ability.on('inputStop', () => {
      this.target.client = null;
      typingSession.detach();
      this.appendLog('inputStop');
    });
    ability.on('keyboardShow', () => {
      this.reloadSettings();
      this.syncChrome();
      this.resize();
      this.panel?.show().catch((err: Error) => {
        hilog.error(0x0000, 'VikeyIME', 'panel show %{public}s', err.message);
      });
    });
    ability.on('keyboardHide', () => {
      emojiModel.open = false;
      emojiModel.searching = false;
      this.searchPanel = false;
    });
    ability.on('securityModeChange', (mode: inputMethodEngine.SecurityMode) => {
      this.appendLog('security ' + mode);
    });
    const delegate = inputMethodEngine.getKeyboardDelegate();
    delegate.on('textChange', (text: string) => {
      typingSession.onDocument(text);
    });
    delegate.on('selectionChange', (_oldBegin: number, _oldEnd: number, newBegin: number, newEnd: number) => {
      typingSession.onSelection(newBegin, newEnd);
    });
    delegate.on('keyDown', (event: inputMethodEngine.KeyEvent): boolean => {
      return this.onHardware(event, true);
    });
    delegate.on('keyUp', (event: inputMethodEngine.KeyEvent): boolean => {
      return this.onHardware(event, false);
    });
  }

  private passwordPattern(pattern: number): boolean {
    return pattern === inputMethod.TextInputType.VISIBLE_PASSWORD ||
      pattern === inputMethod.TextInputType.NUMBER_PASSWORD ||
      pattern === inputMethod.TextInputType.NEW_PASSWORD ||
      pattern === inputMethod.TextInputType.SCREEN_LOCK_PASSWORD;
  }

  private ensurePanel(): void {
    if (this.panel !== null || this.creating || this.context === null || this.ability === null) {
      return;
    }
    this.creating = true;
    const info: inputMethodEngine.PanelInfo = {
      type: inputMethodEngine.PanelType.SOFT_KEYBOARD,
      flag: inputMethodEngine.PanelFlag.FLG_FIXED
    };
    this.ability.createPanel(this.context, info).then((panel: inputMethodEngine.Panel) => {
      this.panel = panel;
      this.creating = false;
      panel.setUiContent('InputMethodExtensionAbility/pages/Index').then(() => {
        this.resize();
        panel.show().catch((err: Error) => {
          hilog.error(0x0000, 'VikeyIME', 'panel show %{public}s', err.message);
        });
      }).catch((err: Error) => {
        hilog.error(0x0000, 'VikeyIME', 'setUiContent %{public}s', err.message);
      });
    }).catch((err: Error) => {
      this.creating = false;
      hilog.error(0x0000, 'VikeyIME', 'createPanel %{public}s', err.message);
    });
  }

  followSystem(): void {
    if (this.context === null) {
      return;
    }
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (_e) {
    }
    this.syncChrome();
  }

  syncChrome(): void {
    if (this.context === null) {
      return;
    }
    let dark = this.context.config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    try {
      const mode = this.context.resourceManager.getConfigurationSync().colorMode as number;
      if (mode === 0) {
        dark = true;
      } else if (mode === 1) {
        dark = false;
      }
    } catch (_e) {
    }
    const prev = AppStorage.get<boolean>('kbDark');
    AppStorage.setOrCreate('kbDark', dark);
    if (prev !== undefined && prev !== dark) {
      const tick = AppStorage.get<number>('kbTick') ?? 0;
      AppStorage.setOrCreate('kbTick', tick + 1);
    }
  }

  hideKeyboard(): void {
    if (this.kb === null) {
      return;
    }
    this.kb.hide().catch(() => {
    });
  }

  /** The emoji search strip is taller than the suggestion bar, so the panel grows while it is open. */
  applySearchPanel(searching: boolean): void {
    if (this.searchPanel === searching) {
      return;
    }
    this.searchPanel = searching;
    this.resize();
  }

  private resize(): void {
    if (this.panel === null) {
      return;
    }
    let dis: display.Display | undefined = undefined;
    try {
      dis = display.getDefaultDisplaySync();
    } catch (_e) {
      return;
    }
    if (dis === undefined) {
      return;
    }
    const reportedW = dis.width;
    const reportedH = dis.height;
    const shortSide = reportedW < reportedH ? reportedW : reportedH;
    const longSide = reportedW > reportedH ? reportedW : reportedH;
    const scale = dis.densityPixels > 0 ? dis.densityPixels : 3.375;
    const compact = shortSide / scale < 500 && reportedW > reportedH;
    const bar = typingSession.settings.suggestions || typingSession.settings.autoCorrect;
    const heightVp = this.searchPanel ? KeyLayout.height(compact, false) + 72 : KeyLayout.height(compact, bar);
    let heightPx = Math.round(heightVp * scale);
    const portraitCap = Math.floor(longSide * 0.69);
    const landscapeCap = Math.floor(shortSide * 0.69);
    if (heightPx > portraitCap) {
      heightPx = portraitCap;
    }
    const landscapeH = heightPx < landscapeCap ? heightPx : landscapeCap;
    const portrait: window.Rect = { left: 0, top: 0, width: shortSide, height: heightPx };
    const landscape: window.Rect = { left: 0, top: 0, width: longSide, height: landscapeH };
    try {
      this.panel.adjustPanelRect(inputMethodEngine.PanelFlag.FLG_FIXED,
        { portraitRect: portrait, landscapeRect: landscape });
      hilog.info(0x0000, 'VikeyIME', 'panel %{public}d x %{public}d', shortSide, heightPx);
    } catch (err) {
      hilog.error(0x0000, 'VikeyIME', 'adjustPanelRect %{public}s', (err as Error).message);
    }
  }

  private onHardware(event: inputMethodEngine.KeyEvent, down: boolean): boolean {
    const code = event.keyCode;
    if (code === KeyCode.KEYCODE_SHIFT_LEFT || code === KeyCode.KEYCODE_SHIFT_RIGHT) {
      this.shiftDown = down;
      return true;
    }
    if (!down) {
      return false;
    }
    if (code === KeyCode.KEYCODE_CAPS_LOCK) {
      this.capsLock = !this.capsLock;
      return true;
    }
    if (code === KeyCode.KEYCODE_DEL) {
      if (emojiModel.searching) {
        emojiModel.deleteQuery();
        typingSession.changed?.();
      } else {
        typingSession.onBackspace();
      }
      return true;
    }
    if (code === KeyCode.KEYCODE_ENTER) {
      typingSession.onReturn();
      return true;
    }
    if (code === KeyCode.KEYCODE_SPACE) {
      if (emojiModel.searching) {
        emojiModel.typeQuery(' ');
        typingSession.changed?.();
      } else {
        typingSession.onSpace();
      }
      return true;
    }
    const ch = this.charOf(code, this.shiftDown !== this.capsLock);
    if (ch.length === 0) {
      return false;
    }
    if (emojiModel.searching) {
      emojiModel.typeQuery(ch);
      typingSession.changed?.();
    } else {
      typingSession.onChar(ch);
    }
    return true;
  }

  private charOf(code: number, shift: boolean): string {
    if (code >= KeyCode.KEYCODE_A && code <= KeyCode.KEYCODE_Z) {
      const letter = String.fromCharCode('a'.charCodeAt(0) + (code - KeyCode.KEYCODE_A));
      return shift ? letter.toUpperCase() : letter;
    }
    if (code >= KeyCode.KEYCODE_0 && code <= KeyCode.KEYCODE_9) {
      const digit = String.fromCharCode('0'.charCodeAt(0) + (code - KeyCode.KEYCODE_0));
      if (!shift) {
        return digit;
      }
      const shifted = [')', '!', '@', '#', '$', '%', '^', '&', '*', '('];
      return shifted[code - KeyCode.KEYCODE_0];
    }
    if (code === KeyCode.KEYCODE_COMMA) { return shift ? '<' : ','; }
    if (code === KeyCode.KEYCODE_PERIOD) { return shift ? '>' : '.'; }
    if (code === KeyCode.KEYCODE_SLASH) { return shift ? '?' : '/'; }
    if (code === KeyCode.KEYCODE_SEMICOLON) { return shift ? ':' : ';'; }
    if (code === KeyCode.KEYCODE_APOSTROPHE) { return shift ? '"' : "'"; }
    if (code === KeyCode.KEYCODE_MINUS) { return shift ? '_' : '-'; }
    if (code === KeyCode.KEYCODE_EQUALS) { return shift ? '+' : '='; }
    if (code === KeyCode.KEYCODE_LEFT_BRACKET) { return shift ? '{' : '['; }
    if (code === KeyCode.KEYCODE_RIGHT_BRACKET) { return shift ? '}' : ']'; }
    if (code === KeyCode.KEYCODE_BACKSLASH) { return shift ? '|' : '\\'; }
    if (code === KeyCode.KEYCODE_GRAVE) { return shift ? '~' : '`'; }
    return '';
  }

  private appendLog(line: string): void {
    if (!this.settings.diagnostics || this.context === null) {
      return;
    }
    try {
      const path = this.context.filesDir + '/keyboard-log.txt';
      const file = fileIo.openSync(path, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.APPEND);
      fileIo.writeSync(file.fd, line + '\n');
      const stat = fileIo.statSync(path);
      fileIo.closeSync(file);
      if (stat.size > 200 * 1024) {
        fileIo.truncateSync(path, 0);
      }
    } catch (_e) {
    }
  }
}

export const keyboardController: KeyboardController = new KeyboardController();
