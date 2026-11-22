import { Driver } from './Driver';

export class CaseResult {
  name: string = '';
  ok: boolean = false;
  got: string = '';
  expected: string = '';
}

/** The 14 live cases from Android/Tests/livetest.py, driven through the same native Driver. */
export class EngineCases {
  static run(): CaseResult[] {
    const specs: string[][] = [
      ['telex_basic', 'vi', 'tieengs vieetj ', 'tiếng việt '],
      ['telex_tone_anywhere', 'vi', 'truowfng truongwf truwownfg ', 'trường trường trường '],
      ['hoa_modern', 'vi', 'hoaf ', 'hoà '],
      ['restore_invalid', 'vi', 'TestFlight ', 'TestFlight '],
      ['auto_vi_to_en_more', 'vi', 'more ', 'more '],
      ['auto_en_word_mid_sentence', 'vi', 'this makes sense ', 'this makes sense '],
      ['auto_double_key_err', 'vi', 'err ', 'err '],
      ['auto_double_key_mix', 'vi', 'mixx ', 'mix '],
      ['auto_en_to_vi', 'en', 'truowfng ', 'trường '],
      ['auto_en_stays_en', 'en', 'the theme of rust ', 'the theme of rust '],
      ['auto_tie_vi_kept', 'vi', 'tô thí ', 'tô thí '],
      ['undo_backspace', 'vi', 'more \\b', 'moẻ'],
      ['identifier_guard', 'en', 'obj.dir my_var ', 'obj.dir my_var '],
      ['hotkey_switch', 'vi', '{alt+z}tieng ', 'tieng ']
    ];
    const results: CaseResult[] = [];
    for (let i = 0; i < specs.length; i++) {
      results.push(EngineCases.one(specs[i][0], specs[i][1], specs[i][2], specs[i][3]));
    }
    return results;
  }

  private static one(name: string, start: string, keys: string, expected: string): CaseResult {
    const driver = new Driver();
    driver.autoSwitch = true;
    driver.pauseAfterManual = 5;
    driver.modernOrthography = true;
    driver.telexStyle = 0;
    driver.spelling = true;
    driver.restoreIfInvalid = true;
    driver.applySettings();
    driver.language = start === 'vi' ? 1 : 0;
    let text = '';
    let now = 1000;
    const parts = EngineCases.split(keys);
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      now += 0.05;
      if (part === '{alt+z}') {
        driver.manualSwitch(now);
        continue;
      }
      for (let c = 0; c < part.length; c++) {
        now += 0.02;
        const ch = part.charAt(c);
        const edit = ch === '\b' ? driver.backspace(now) : driver.typeCharacter(ch, now);
        text = EngineCases.apply(text, edit.deleteCount, edit.text);
      }
    }
    driver.close();
    const result = new CaseResult();
    result.name = name;
    result.got = text;
    result.expected = expected;
    result.ok = text === expected;
    return result;
  }

  private static apply(text: string, deletes: number, insert: string): string {
    let next = text;
    let remove = deletes;
    let add = insert;
    if (remove > 0 && next.length >= remove) {
      const old = next.substring(next.length - remove);
      let same = 0;
      while (same < old.length && same < add.length && old.charAt(same) === add.charAt(same)) {
        same++;
      }
      remove -= same;
      add = add.substring(same);
    }
    if (remove > next.length) {
      remove = next.length;
    }
    if (remove > 0) {
      next = next.substring(0, next.length - remove);
    }
    return next + add;
  }

  private static split(keys: string): string[] {
    const out: string[] = [];
    let buf = '';
    for (let i = 0; i < keys.length; i++) {
      if (keys.startsWith('\\b', i)) {
        if (buf.length > 0) { out.push(buf); buf = ''; }
        out.push('\b');
        i += 1;
      } else if (keys.startsWith('\\n', i)) {
        if (buf.length > 0) { out.push(buf); buf = ''; }
        out.push('\n');
        i += 1;
      } else if (keys.startsWith('{alt+z}', i)) {
        if (buf.length > 0) { out.push(buf); buf = ''; }
        out.push('{alt+z}');
        i += 6;
      } else {
        buf += keys.charAt(i);
      }
    }
    if (buf.length > 0) {
      out.push(buf);
    }
    return out;
  }
}
