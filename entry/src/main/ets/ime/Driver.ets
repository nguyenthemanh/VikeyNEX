import vikey from 'libvikey.so';

/** An edit the engine wants applied before the cursor. Packed like VikeyDriver.kt. */
export class Edit {
  deleteCount: number = 0;
  text: string = '';
  languageChanged: boolean = false;

  static unpack(packed: string): Edit {
    const edit = new Edit();
    if (packed.length < 2) {
      edit.text = packed;
      return edit;
    }
    edit.deleteCount = packed.charCodeAt(0);
    edit.languageChanged = packed.charCodeAt(1) === 1;
    edit.text = packed.substring(2);
    return edit;
  }
}

/** A word the touch model offers. */
export class Candidate {
  letters: string = '';
  text: string = '';
  vietnamese: boolean = false;
  score: number = 0;

  packed(): string {
    return this.letters + '\t' + this.text + '\t' + (this.vietnamese ? '1' : '0') + '\t' + this.score;
  }

  static unpack(packed: string): Candidate {
    const candidate = new Candidate();
    const parts = packed.split('\t');
    candidate.letters = parts.length > 0 ? parts[0] : '';
    candidate.text = parts.length > 1 ? parts[1] : '';
    candidate.vietnamese = parts.length > 2 && parts[2] === '1';
    const score = parts.length > 3 ? Number.parseFloat(parts[3]) : 0;
    candidate.score = Number.isNaN(score) ? 0 : score;
    return candidate;
  }
}

/** One VikeyDriver. The handle is a slot id, not a raw pointer. */
export class Driver {
  private handle: number = 0;
  autoSwitch: boolean = true;
  pauseAfterManual: number = 5;
  modernOrthography: boolean = true;
  telexStyle: number = 0;
  spelling: boolean = true;
  restoreIfInvalid: boolean = true;

  constructor() {
    this.handle = vikey.create();
  }

  get language(): number {
    return vikey.language(this.handle);
  }

  set language(value: number) {
    vikey.setLanguage(this.handle, value);
  }

  applySettings(): void {
    vikey.configure(this.handle, this.autoSwitch, this.pauseAfterManual, this.spelling, this.restoreIfInvalid,
      this.modernOrthography);
    vikey.setTelexStyle(this.telexStyle);
  }

  typeCharacter(text: string, now: number): Edit {
    if (text.length !== 1) {
      this.resetContext();
      const edit = new Edit();
      edit.text = text;
      return edit;
    }
    return Edit.unpack(vikey.typeChar(this.handle, text, now));
  }

  backspace(now: number): Edit {
    return Edit.unpack(vikey.backspace(this.handle, now));
  }

  manualSwitch(now: number): void {
    vikey.manualSwitch(this.handle, now);
  }

  resetContext(): void {
    vikey.resetContext(this.handle);
  }

  close(): void {
    if (this.handle !== 0) {
      vikey.destroy(this.handle);
      this.handle = 0;
    }
  }

  static pickLetter(x: number, y: number, prefix: string, vietnamese: boolean, letters: string,
    rects: number[]): string {
    const code = vikey.pickLetter(x, y, prefix, vietnamese ? 1 : 0, letters, rects);
    if (code === 0) {
      return '';
    }
    return String.fromCharCode(code);
  }

  static candidates(typed: string, xs: number[], ys: number[], vietnamese: boolean, letters: string,
    rects: number[], max: number): Candidate[] {
    const packed = vikey.candidates(typed, xs, ys, vietnamese ? 1 : 0, letters, rects, max);
    const out: Candidate[] = [];
    for (let i = 0; i < packed.length; i++) {
      out.push(Candidate.unpack(packed[i]));
    }
    return out;
  }

  static shouldCorrect(typed: string, list: Candidate[]): boolean {
    const packed: string[] = [];
    for (let i = 0; i < list.length; i++) {
      packed.push(list[i].packed());
    }
    return vikey.shouldCorrect(typed, packed);
  }

  static completions(prefix: string, vietnamese: boolean, max: number): Candidate[] {
    const packed = vikey.completions(prefix, vietnamese ? 1 : 0, max);
    const out: Candidate[] = [];
    for (let i = 0; i < packed.length; i++) {
      out.push(Candidate.unpack(packed[i]));
    }
    return out;
  }

  static wordScore(vietnamese: boolean, letters: string): number {
    return vikey.wordScore(vietnamese ? 1 : 0, letters);
  }

  /** Vietnamese words these plain letters can be, most common first: "toi" → tôi, tới, tội. */
  static accentForms(typed: string, max: number): string[] {
    try {
      const list = vikey.accentForms(typed, max);
      return list === undefined ? [] : list;
    } catch (_e) {
      return [];
    }
  }
}
