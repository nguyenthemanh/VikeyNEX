import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

/** Settings the app writes and the keyboard reads. Keys match the Android app.
 *  Stored as one JSON file in the module files directory. Preferences are not safe
 *  across the UIAbility process and the input-method process.
 */
export class VikeySettings {
  autoSwitch: boolean = true;
  pause: boolean = true;
  modern: boolean = true;
  telexStyle: number = 0;
  spelling: boolean = true;
  restore: boolean = true;
  webEnglish: boolean = true;
  autoCap: boolean = true;
  doubleSpace: boolean = true;
  haptics: boolean = true;
  diagnostics: boolean = false;
  suggestions: boolean = true;
  autoCorrect: boolean = true;
  language: number = 1;
  didOnboard: boolean = false;
  emojiTone: number = 0;
  emojiUsage: string = '';
}

export class SettingsStore {
  static path(context: common.Context): string {
    return context.filesDir + '/vikey-settings.json';
  }

  static load(context: common.Context): VikeySettings {
    const settings = new VikeySettings();
    try {
      const text = fileIo.readTextSync(SettingsStore.path(context));
      SettingsStore.apply(settings, text);
    } catch (_e) {
    }
    return settings;
  }

  static save(context: common.Context, settings: VikeySettings): void {
    const file = fileIo.openSync(SettingsStore.path(context),
      fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.TRUNC);
    fileIo.writeSync(file.fd, SettingsStore.serialize(settings));
    fileIo.closeSync(file);
  }

  private static serialize(settings: VikeySettings): string {
    return JSON.stringify({
      autoSwitch: settings.autoSwitch,
      pause: settings.pause,
      modern: settings.modern,
      telexStyle: settings.telexStyle,
      spelling: settings.spelling,
      restore: settings.restore,
      webEnglish: settings.webEnglish,
      autoCap: settings.autoCap,
      doubleSpace: settings.doubleSpace,
      haptics: settings.haptics,
      diagnostics: settings.diagnostics,
      suggestions: settings.suggestions,
      autoCorrect: settings.autoCorrect,
      language: settings.language,
      didOnboard: settings.didOnboard,
      emojiTone: settings.emojiTone,
      emojiUsage: settings.emojiUsage
    });
  }

  private static apply(settings: VikeySettings, text: string): void {
    const raw = JSON.parse(text) as Record<string, Object>;
    settings.autoSwitch = SettingsStore.bool(raw, 'autoSwitch', true);
    settings.pause = SettingsStore.bool(raw, 'pause', true);
    settings.modern = SettingsStore.bool(raw, 'modern', true);
    settings.telexStyle = SettingsStore.num(raw, 'telexStyle', 0);
    settings.spelling = SettingsStore.bool(raw, 'spelling', true);
    settings.restore = SettingsStore.bool(raw, 'restore', true);
    settings.webEnglish = SettingsStore.bool(raw, 'webEnglish', true);
    settings.autoCap = SettingsStore.bool(raw, 'autoCap', true);
    settings.doubleSpace = SettingsStore.bool(raw, 'doubleSpace', true);
    settings.haptics = SettingsStore.bool(raw, 'haptics', true);
    settings.diagnostics = SettingsStore.bool(raw, 'diagnostics', false);
    settings.suggestions = SettingsStore.bool(raw, 'suggestions', true);
    settings.autoCorrect = SettingsStore.bool(raw, 'autoCorrect', true);
    settings.language = SettingsStore.num(raw, 'language', 1);
    settings.didOnboard = SettingsStore.bool(raw, 'didOnboard', false);
    settings.emojiTone = SettingsStore.num(raw, 'emojiTone', 0);
    settings.emojiUsage = SettingsStore.str(raw, 'emojiUsage', '');
  }

  private static bool(raw: Record<string, Object>, key: string, fallback: boolean): boolean {
    const value = raw[key];
    return typeof value === 'boolean' ? value : fallback;
  }

  private static num(raw: Record<string, Object>, key: string, fallback: number): number {
    const value = raw[key];
    return typeof value === 'number' ? value : fallback;
  }

  private static str(raw: Record<string, Object>, key: string, fallback: string): string {
    const value = raw[key];
    return typeof value === 'string' ? value : fallback;
  }
}
