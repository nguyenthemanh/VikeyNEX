import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';
import { TelexSearch } from './TelexSearch';
import { SettingsStore, VikeySettings } from '../model/SettingsStore';

/** One emoji-panel category. group -1 is recents, -2 is HarmonyOS text faces. */
export class EmojiCategory {
  icon: string = '';
  group: number = -1;
}

class EmojiItem {
  char: string = '';
  group: number = 0;
  name: string = '';
  folded: string = '';
  skins: string[] = [];
  popularity: number = 0;
}

/** Emoji catalog, recents, and Telex/English/Vietnamese search. Local only. */
export class EmojiModel {
  open: boolean = false;
  searching: boolean = false;
  query: string = '';
  tone: number = 0;
  group: number = -1;
  cells: string[] = [];
  ready: boolean = false;
  private items: EmojiItem[] = [];
  private usage: string = '';
  private context: common.Context | null = null;

  setUsage(value: string): void {
    this.usage = value;
  }

  bind(context: common.Context, settings: VikeySettings): void {
    this.context = context;
    this.tone = settings.emojiTone;
    this.usage = settings.emojiUsage;
    if (!this.ready) {
      this.load(context);
    }
    this.refresh();
  }

  private load(context: common.Context): void {
    try {
      const bytes = context.resourceManager.getRawFileContentSync('Emoji.json');
      const text = util.TextDecoder.create('utf-8').decodeToString(bytes);
      const rows = JSON.parse(text) as Object[];
      const items: EmojiItem[] = [];
      for (let i = 0; i < rows.length; i++) {
        const row = rows[i] as Object[];
        if (row.length < 8) {
          continue;
        }
        const item = new EmojiItem();
        item.char = String(row[0]);
        item.group = Number(row[1]);
        const en = String(row[3]);
        const vi = String(row[4]);
        const keys = String(row[5]) + ' ' + String(row[6]);
        let emoticon = '';
        if (row.length > 9) {
          emoticon = String(row[9]);
        }
        item.name = (en + ' ' + vi + ' ' + keys + ' ' + emoticon).toLowerCase();
        item.folded = EmojiModel.fold(item.name);
        if (Array.isArray(row[7])) {
          const skins = row[7] as Object[];
          for (let s = 0; s < skins.length; s++) {
            item.skins.push(String(skins[s]));
          }
        }
        if (row.length > 8 && typeof row[8] === 'number') {
          item.popularity = Number(row[8]);
        }
        if (item.char.length > 0) {
          items.push(item);
        }
      }
      this.items = items;
      this.ready = true;
    } catch (_e) {
      this.ready = false;
    }
  }

  /** iOS categories, with People split out, plus the HarmonyOS text-face page. */
  static categories(): EmojiCategory[] {
    const icons = ['★', '😀', '👋', '🐻', '🍔', '🏀', '🚗', '💡', '♥', '🏁', '☺'];
    const groups = [-1, 0, 1, 3, 4, 6, 5, 7, 8, 9, -2];
    const list: EmojiCategory[] = [];
    for (let i = 0; i < icons.length; i++) {
      const cat = new EmojiCategory();
      cat.icon = icons[i];
      cat.group = groups[i];
      list.push(cat);
    }
    return list;
  }

  refresh(): void {
    if (this.searching) {
      this.cells = this.query.trim().length > 0 ? this.search(this.query) : this.frequent();
      return;
    }
    if (this.group === -2) {
      this.cells = this.kaomoji();
      return;
    }
    if (this.group < 0) {
      this.cells = this.frequent();
      return;
    }
    const out: string[] = [];
    for (let i = 0; i < this.items.length; i++) {
      if (this.items[i].group === this.group) {
        out.push(this.withTone(this.items[i]));
      }
    }
    this.cells = out;
  }

  private kaomoji(): string[] {
    return ['(^_^)', '(≧▽≦)', '(￣▽￣)', '(¬_¬)', '(T_T)', '(ಠ_ಠ)',
      '(╯°□°）╯', '╮(╯▽╰)╭', '¯\\_(ツ)_/¯', '(ノ°益°)ノ', '(ง •̀_•́)ง', '(☞ﾟヮﾟ)☞',
      '(｡♥‿♥｡)', '(*^▽^*)', '(✿◠‿◠)', '(づ｡◕‿◕｡)づ', '(￣ω￣)', '(=^･ω･^=)',
      '(｡•́︿•̀｡)', '(；￣Д￣)', '(๑•̀ㅂ•́)و', '♪(^∇^*)', '(•̀ᴗ•́)و', '(￣ε￣)'];
  }

  typeQuery(text: string): void {
    this.query += text;
    this.refresh();
  }

  deleteQuery(): void {
    if (this.query.length === 0) {
      return;
    }
    const last = this.query.charCodeAt(this.query.length - 1);
    const cut = this.query.length >= 2 && last >= 0xDC00 && last <= 0xDFFF ? 2 : 1;
    this.query = this.query.substring(0, this.query.length - cut);
    this.refresh();
  }

  record(text: string): void {
    const scores = this.readUsage();
    const keys = scores.keys();
    const next: string[][] = [];
    while (true) {
      const step = keys.next();
      if (step.done) {
        break;
      }
      const key = step.value as string;
      const faded = (scores.get(key) ?? 0) * 0.97;
      if (key !== text) {
        next.push([key, String(faded)]);
      }
    }
    next.push([text, String((scores.get(text) ?? 0) * 0.97 + 1)]);
    next.sort((a: string[], b: string[]) => Number.parseFloat(b[1]) - Number.parseFloat(a[1]));
    const kept = next.slice(0, 80);
    let stored = '';
    for (let i = 0; i < kept.length; i++) {
      if (i > 0) {
        stored += '\n';
      }
      stored += kept[i][0] + '\t' + kept[i][1];
    }
    this.usage = stored;
    if (this.context !== null) {
      const settings = SettingsStore.load(this.context);
      settings.emojiUsage = stored;
      settings.emojiTone = this.tone;
      SettingsStore.save(this.context, settings);
    }
  }

  private frequent(): string[] {
    const scores = this.readUsage();
    const ranked: string[] = [];
    const entries: string[][] = [];
    const keys = scores.keys();
    while (true) {
      const step = keys.next();
      if (step.done) {
        break;
      }
      const key = step.value as string;
      entries.push([key, String(scores.get(key) ?? 0)]);
    }
    entries.sort((a: string[], b: string[]) => Number.parseFloat(b[1]) - Number.parseFloat(a[1]));
    for (let i = 0; i < entries.length && ranked.length < 32; i++) {
      ranked.push(entries[i][0]);
    }
    const starter = ['😂', '❤️', '🥰', '😍', '😭', '👍', '🙏', '😊', '🔥', '😘', '🤣', '🥺', '😅', '🎉', '💕', '😁'];
    for (let i = 0; i < starter.length && ranked.length < 32; i++) {
      if (ranked.indexOf(starter[i]) < 0) {
        ranked.push(starter[i]);
      }
    }
    return ranked;
  }

  private search(raw: string): string[] {
    const query = raw.toLowerCase().trim();
    const telex = TelexSearch.convert(query);
    const folded = EmojiModel.fold(query);
    const foldedTelex = EmojiModel.fold(telex);
    const scored: string[][] = [];
    for (let i = 0; i < this.items.length; i++) {
      const item = this.items[i];
      let score = 0;
      if (item.name.indexOf(query) >= 0) {
        score = 80;
      } else if (item.folded.indexOf(folded) >= 0) {
        score = 60;
      } else if (telex !== query && item.folded.indexOf(foldedTelex) >= 0) {
        score = 55;
      }
      if (score > 0) {
        scored.push([this.withTone(item), String(score + item.popularity), String(i)]);
      }
    }
    scored.sort((a: string[], b: string[]) => Number.parseFloat(b[1]) - Number.parseFloat(a[1]));
    const out: string[] = [];
    for (let i = 0; i < scored.length && out.length < 80; i++) {
      out.push(scored[i][0]);
    }
    return out;
  }

  private withTone(item: EmojiItem): string {
    if (this.tone > 0 && item.skins.length === 5) {
      return item.skins[this.tone - 1];
    }
    return item.char;
  }

  private readUsage(): Map<string, number> {
    const map = new Map<string, number>();
    const lines = this.usage.split('\n');
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      const tab = line.lastIndexOf('\t');
      if (tab > 0) {
        const score = Number.parseFloat(line.substring(tab + 1));
        if (!Number.isNaN(score)) {
          map.set(line.substring(0, tab), score);
        }
      }
    }
    return map;
  }

  private static fold(text: string): string {
    let out = text.toLowerCase();
    const from = 'àáảãạăằắẳẵặâầấẩẫậèéẻẽẹêềếểễệìíỉĩịòóỏõọôồốổỗộơờớởỡợùúủũụưừứửữựỳýỷỹỵđ';
    const to = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    let folded = '';
    for (let i = 0; i < out.length; i++) {
      const ch = out.charAt(i);
      const at = from.indexOf(ch);
      folded += at >= 0 ? to.charAt(at) : ch;
    }
    return folded;
  }
}

export const emojiModel: EmojiModel = new EmojiModel();
