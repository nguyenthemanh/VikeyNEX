import { inputMethodEngine } from '@kit.IMEKit';
import { inputMethod } from '@kit.IMEKit';
import { Candidate, Driver, Edit } from './Driver';
import { Contractions } from './Contractions';
import { nextWords } from './NextWords';
import { VikeySettings } from '../model/SettingsStore';

export class Suggestion {
  text: string = '';
  quoted: boolean = false;
  highlighted: boolean = false;
  kind: string = 'word';
}

/** What the keyboard can do to the focused field. */
export interface TextTarget {
  insert(text: string): void;
  deleteBack(count: number): void;
  sendAction(action: number): void;
  moveLeft(steps: number): void;
  moveRight(steps: number): void;
  readBefore(max: number): string;
  readAfter(max: number): string;
}

class Correction {
  typed: string = '';
  inserted: string = '';
}

/** Typing behaviour of the Android VikeyIME, applied through InputClient. */
export class TypingSession {
  driver: Driver = new Driver();
  target: TextTarget | null = null;
  settings: VikeySettings = new VikeySettings();
  layer: number = 0;
  shift: number = 0;
  suggestions: Suggestion[] = [];
  returnTitleKey: string = '';
  returnBlue: boolean = false;
  enterKey: number = 0;
  multiline: boolean = false;
  password: boolean = false;
  webField: boolean = false;
  secure: boolean = false;
  showsGlobe: boolean = false;
  previewOn: boolean = false;
  previewFrom: string = '';
  previewTo: string = '';
  diagnostics: string = '';
  changed: (() => void) | null = null;
  persistLanguage: ((language: number) => void) | null = null;
  private fieldLanguage: number = -1;
  private lastContext: string = '';
  private cursorPos: number = -1;
  private recentPositions: number[] = [];
  private wordPrefix: string = '';
  private wordXs: number[] = [];
  private wordYs: number[] = [];
  private wordCaps: number = 0;
  private letters: string = '';
  private rects: number[] = [];
  private candidates: Candidate[] = [];
  private willCorrect: boolean = false;
  private pendingText: string = '';
  private pendingVi: boolean = false;
  private hasPending: boolean = false;
  private lastCorrection: Correction | null = null;
  private keepWord: string = '';
  private fullText: string = '';
  private selBegin: number = 0;
  private selEnd: number = 0;
  private selection: string = '';
  private review: string = '';
  private appliedOriginal: string = '';
  private appliedInserted: string = '';
  private lastSpace: number = 0;
  private lastShiftTap: number = 0;
  private touchX: number = 0;
  private touchY: number = 0;
  private hasTouch: boolean = false;
  private suggestToken: number = 0;

  reload(settings: VikeySettings): void {
    this.settings = settings;
    this.driver.autoSwitch = settings.autoSwitch;
    this.driver.pauseAfterManual = settings.pause ? 5 : 0;
    this.driver.modernOrthography = settings.modern;
    this.driver.telexStyle = settings.telexStyle;
    this.driver.spelling = settings.spelling;
    this.driver.restoreIfInvalid = settings.restore;
    this.driver.applySettings();
    this.driver.language = settings.language === 0 ? 0 : 1;
    this.publish();
  }

  setGeometry(letters: string, rects: number[]): void {
    this.letters = letters;
    this.rects = rects;
  }

  rememberTouch(x: number, y: number): void {
    this.touchX = x;
    this.touchY = y;
    this.hasTouch = true;
  }

  attach(target: TextTarget, pattern: number, enter: number, secure: boolean): void {
    this.target = target;
    this.secure = secure;
    this.enterKey = enter;
    this.password = pattern === inputMethod.TextInputType.VISIBLE_PASSWORD ||
      pattern === inputMethod.TextInputType.NUMBER_PASSWORD ||
      pattern === inputMethod.TextInputType.NEW_PASSWORD ||
      pattern === inputMethod.TextInputType.SCREEN_LOCK_PASSWORD;
    this.webField = pattern === inputMethod.TextInputType.URL || pattern === inputMethod.TextInputType.EMAIL_ADDRESS;
    this.multiline = pattern === inputMethod.TextInputType.MULTILINE || enter === inputMethod.EnterKeyType.NEWLINE;
    this.returnTitleKey = this.actionTitle();
    this.returnBlue = this.returnTitleKey.length > 0 && this.returnTitleKey !== 'ret_next';
    this.driver.resetContext();
    if (this.password || (this.webField && this.settings.webEnglish)) {
      if (this.fieldLanguage < 0) {
        this.fieldLanguage = this.driver.language;
      }
      this.driver.language = 0;
    } else if (this.fieldLanguage >= 0) {
      this.driver.language = this.fieldLanguage;
      this.fieldLanguage = -1;
    }
    this.lastContext = this.safeRead();
    this.cursorPos = this.lastContext.length;
    this.recentPositions = [];
    this.lastCorrection = null;
    this.keepWord = '';
    this.clearWord();
    if (pattern === inputMethod.TextInputType.NUMBER || pattern === inputMethod.TextInputType.PHONE ||
      pattern === inputMethod.TextInputType.NUMBER_DECIMAL) {
      this.layer = 1;
    } else {
      this.layer = 0;
    }
    this.updateAutoShift(this.lastContext);
    this.publish();
  }

  detach(): void {
    this.target = null;
    this.clearWord();
    this.publish();
  }

  wordContext(): string[] {
    return [this.wordPrefix.toLowerCase(), this.driver.language === 1 ? '1' : '0'];
  }

  onChar(raw: string): void {
    this.leaveSelection();
    let text = raw;
    if (text.length !== 1) {
      this.insertPlain(text);
      return;
    }
    if (!this.password && this.snapsBack(text)) {
      this.deleteBack(1);
      this.driver.resetContext();
      this.afterEdit(1, '');
    }
    const before = this.lastContext;
    if (text === '-' && before.endsWith('-') && !before.endsWith('--') && this.smartHere()) {
      this.backspace();
      this.clearWord();
      this.type('—');
      return;
    }
    this.lastCorrection = null;
    if ((text === '.' || text === ',' || text === '?' || text === '!') && this.wordPrefix.length > 0 &&
      this.autoCorrectAtBreak(text)) {
      if (text !== ',') {
        this.updateAutoShift(this.lastContext);
      }
      this.publish();
      return;
    }
    const ch = text.charAt(0);
    if (this.isAsciiLetter(ch) && this.wordPrefix.length < 30) {
      this.wordPrefix += ch;
      this.wordXs.push(this.hasTouch ? this.touchX : Number.NaN);
      this.wordYs.push(this.hasTouch ? this.touchY : Number.NaN);
      this.hasTouch = false;
      if (this.layer === 0 && this.shift !== 0) {
        this.wordCaps++;
      }
    } else {
      this.clearWord();
    }
    if (this.layer === 0 && this.shift !== 0) {
      text = text.toUpperCase();
    }
    this.type(text);
    if (this.shift === 1) {
      this.shift = 0;
    }
    if (this.layer !== 0 && text === "'") {
      this.layer = 0;
    }
    this.publish();
  }

  onSpace(): void {
    this.leaveSelection();
    if (!this.autoCorrectAtBreak(' ')) {
      this.spaceKey();
    }
    this.clearWord();
    this.publish();
  }

  onReturn(): void {
    this.leaveSelection();
    this.clearWord();
    if (this.returnTitleKey.length > 0) {
      if (!this.password) {
        const edit = this.driver.typeCharacter('\n', this.now());
        const text = edit.text.endsWith('\n') ? edit.text.substring(0, edit.text.length - 1) : edit.text;
        this.apply(edit.deleteCount, text, edit.languageChanged);
      }
      this.driver.resetContext();
      if (this.target !== null) {
        this.target.sendAction(this.enterKey);
      }
    } else {
      this.type('\n');
    }
    this.publish();
  }

  onBackspace(): void {
    this.leaveSelection();
    if (this.undoCorrection()) {
      this.publish();
      return;
    }
    this.backspace();
    this.publish();
  }

  onBackspaceRepeat(count: number): void {
    if (count <= 20) {
      this.backspace();
      this.publish();
      return;
    }
    const before = this.lastContext;
    if (before.length === 0) {
      return;
    }
    let end = before.length;
    let removed = 0;
    while (end > 0 && before.charAt(end - 1) === ' ') {
      end--;
      removed++;
    }
    while (end > 0 && before.charAt(end - 1) !== ' ' && before.charAt(end - 1) !== '\n') {
      end--;
      removed++;
    }
    if (removed < 1) {
      removed = 1;
    }
    this.deleteBack(removed);
    this.driver.resetContext();
    this.clearWord();
    this.afterEdit(removed, '');
    this.publish();
  }

  onAlternate(text: string): void {
    this.clearWord();
    this.type(text);
    if (this.shift === 1) {
      this.shift = 0;
    }
    this.publish();
  }

  onShift(): void {
    const t = this.now();
    if (this.shift === 2) {
      this.shift = 0;
    } else if (t - this.lastShiftTap < 0.35) {
      this.shift = 2;
    } else if (this.shift === 1) {
      this.shift = 0;
    } else {
      this.shift = 1;
    }
    this.lastShiftTap = t;
    this.publish();
  }

  onLayer(layer: number): void {
    this.layer = layer;
    this.publish();
  }

  onLanguage(): void {
    this.lastCorrection = null;
    this.driver.manualSwitch(this.now());
    this.fieldLanguage = -1;
    this.settings.language = this.driver.language;
    if (this.persistLanguage !== null) {
      this.persistLanguage(this.driver.language);
    }
    this.publish();
  }

  onMoveCursor(by: number): void {
    if (this.target === null || by === 0) {
      return;
    }
    if (by < 0) {
      this.target.moveLeft(-by);
    } else {
      this.target.moveRight(by);
    }
    this.cursorPos = Math.max(0, this.cursorPos + by);
  }

  onCursorEnd(): void {
    this.driver.resetContext();
    this.clearWord();
    this.lastCorrection = null;
    this.keepWord = '';
    this.lastContext = this.safeRead();
    this.updateAutoShift(this.lastContext);
    this.publish();
  }

  onOutsideChange(): void {
    this.driver.resetContext();
    this.clearWord();
    this.lastCorrection = null;
    this.keepWord = '';
    this.recentPositions = [];
    this.lastContext = this.safeRead();
    this.cursorPos = this.lastContext.length;
    this.updateAutoShift(this.lastContext);
    this.publish();
  }

  pickSuggestion(index: number): void {
    if (index < 0 || index >= this.suggestions.length) {
      return;
    }
    const cell = this.suggestions[index];
    if (cell.kind === 'busy') {
      return;
    }
    if (cell.kind === 'proofread') {
      this.runProofread();
      return;
    }
    if (cell.kind === 'alternative') {
      this.replaceSelection(cell.text);
      return;
    }
    if (cell.kind === 'undo') {
      this.undoApplied();
      return;
    }
    if (cell.kind === 'next') {
      this.insertPlain(cell.text + ' ');
      return;
    }
    this.lastCorrection = null;
    if (cell.quoted || cell.text === this.shownWord()) {
      this.keepWord = this.wordPrefix.toLowerCase();
      this.willCorrect = false;
      this.spaceKey();
      this.clearWord();
      this.publish();
      return;
    }
    let vi = this.driver.language === 1;
    for (let i = 0; i < this.candidates.length; i++) {
      if (this.cased(this.candidates[i].text) === cell.text) {
        vi = this.candidates[i].vietnamese;
      }
    }
    this.replaceWord(cell.text, vi, false, ' ');
    this.publish();
  }

  insertPlain(text: string): void {
    this.clearWord();
    this.driver.resetContext();
    if (this.target !== null && text.length > 0) {
      this.target.insert(text);
    }
    this.afterEdit(0, text);
    this.publish();
  }

  private type(text: string): void {
    if (this.password || this.secure) {
      const edit = new Edit();
      edit.text = text;
      this.apply(0, text, false);
      return;
    }
    const edit = this.driver.typeCharacter(text, this.now());
    this.apply(edit.deleteCount, edit.text, edit.languageChanged);
  }

  private apply(deleteCount: number, insert: string, languageChanged: boolean): void {
    let deletes = deleteCount;
    let text = insert;
    if (deletes > 0 && this.lastContext.length >= deletes) {
      const old = this.lastContext.substring(this.lastContext.length - deletes);
      let same = 0;
      while (same < old.length && same < text.length && old.charAt(same) === text.charAt(same)) {
        same++;
      }
      deletes -= same;
      text = text.substring(same);
    }
    if (deletes > 0) {
      this.deleteBack(deletes);
    }
    if (text.length > 0 && this.target !== null) {
      this.target.insert(text);
    }
    if (languageChanged) {
      this.settings.language = this.driver.language;
      if (this.persistLanguage !== null) {
        this.persistLanguage(this.driver.language);
      }
    }
    this.afterEdit(deletes, text);
  }

  private afterEdit(deleted: number, inserted: string): void {
    let context = this.lastContext;
    const drop = Math.min(deleted, context.length);
    context = context.substring(0, context.length - drop) + inserted;
    if (context.length > 4000) {
      context = context.substring(context.length - 2000);
    }
    this.lastContext = context;
    if (this.cursorPos >= 0) {
      this.cursorPos = Math.max(0, this.cursorPos - deleted) + inserted.length;
      this.recentPositions.push(this.cursorPos);
      if (this.recentPositions.length > 12) {
        this.recentPositions.shift();
      }
    }
    this.updateAutoShift(context);
    this.queueSuggestions();
  }

  private queueSuggestions(): void {
    this.suggestToken++;
    const token = this.suggestToken;
    setTimeout(() => {
      if (token !== this.suggestToken) {
        return;
      }
      this.updateSuggestions();
      this.publish();
    }, 0);
  }

  private spaceKey(): void {
    const before = this.lastContext;
    const t = this.now();
    if (this.settings.doubleSpace && !this.password && t - this.lastSpace < 0.6 && before.endsWith(' ') &&
      before.length >= 2 && this.isLetterOrDigit(before.charAt(before.length - 2))) {
      this.deleteBack(1);
      if (this.target !== null) {
        this.target.insert('. ');
      }
      this.driver.resetContext();
      this.lastSpace = 0;
      this.afterEdit(1, '. ');
      return;
    }
    this.type(' ');
    this.lastSpace = t;
    if (this.layer !== 0) {
      this.layer = 0;
    }
  }

  private backspace(): void {
    if (this.wordPrefix.length > 0) {
      this.wordPrefix = this.wordPrefix.substring(0, this.wordPrefix.length - 1);
      this.wordXs.pop();
      this.wordYs.pop();
      if (this.wordCaps > this.wordPrefix.length) {
        this.wordCaps = this.wordPrefix.length;
      }
    }
    const before = this.lastContext;
    if (before.length > 0 && this.wordPrefix.length === 0 && !this.isLetterOrDigit(before.charAt(before.length - 1))) {
      const n = this.lastGrapheme(before);
      if (n > 1) {
        this.deleteBack(n);
        this.driver.resetContext();
        this.afterEdit(n, '');
        return;
      }
    }
    if (this.password || this.secure) {
      this.deleteBack(1);
      this.afterEdit(1, '');
      return;
    }
    const edit = this.driver.backspace(this.now());
    this.apply(edit.deleteCount, edit.text, edit.languageChanged);
  }

  private deleteBack(count: number): void {
    if (count > 0 && this.target !== null) {
      this.target.deleteBack(count);
    }
  }

  private clearWord(): void {
    this.wordPrefix = '';
    this.wordXs = [];
    this.wordYs = [];
    this.wordCaps = 0;
    this.candidates = [];
    this.willCorrect = false;
    this.hasPending = false;
    this.pendingText = '';
    this.suggestions = [];
  }

  private shownWord(): string {
    let i = this.lastContext.length;
    while (i > 0 && this.isLetter(this.lastContext.charAt(i - 1))) {
      i--;
    }
    return this.lastContext.substring(i);
  }

  private cased(text: string): string {
    const shown = this.shownWord();
    if (shown.length > 0 && this.isUpper(shown.charAt(0)) && text.length > 0) {
      return text.substring(0, 1).toUpperCase() + text.substring(1);
    }
    return text;
  }

  private correctsHere(): boolean {
    if (this.password || this.secure || this.webField) {
      return false;
    }
    return true;
  }

  private smartHere(): boolean {
    return this.correctsHere();
  }

  private updateSuggestions(): void {
    this.suggestToken++;
    if (this.review.length > 0) {
      return;
    }
    const bar = this.settings.suggestions || this.settings.autoCorrect;
    if (!bar || !this.correctsHere()) {
      this.suggestions = [];
      this.willCorrect = false;
      this.hasPending = false;
      return;
    }
    if (this.wordPrefix.length === 0 || this.shownWord().length === 0) {
      this.fillNextWords();
      return;
    }
    const typed = this.wordPrefix.toLowerCase();
    const vi = this.driver.language === 1;
    let touched = true;
    for (let i = 0; i < this.wordXs.length; i++) {
      if (Number.isNaN(this.wordXs[i])) {
        touched = false;
      }
    }
    try {
      this.candidates = Driver.candidates(typed, touched ? this.wordXs : [], touched ? this.wordYs : [], vi,
        this.letters, this.rects, 6);
    } catch (_e) {
      this.candidates = [];
    }
    this.willCorrect = this.settings.autoCorrect && this.wordCaps < 2 && this.keepWord !== typed &&
      this.wordPrefix.length >= 3 && Driver.shouldCorrect(typed, this.candidates);
    this.hasPending = false;
    if (this.willCorrect && this.candidates.length > 0) {
      this.pendingText = this.cased(this.candidates[0].text);
      this.pendingVi = this.candidates[0].vietnamese;
      this.hasPending = true;
    }
    const shownNow = this.shownWord();
    let typedCased = typed;
    if (this.wordCaps === this.wordPrefix.length && this.wordPrefix.length > 1) {
      typedCased = typed.toUpperCase();
    } else if (shownNow.length > 0 && this.isUpper(shownNow.charAt(0))) {
      typedCased = typed.substring(0, 1).toUpperCase() + typed.substring(1);
    }
    if (this.settings.autoCorrect && this.keepWord !== typed) {
      const contraction = Contractions.fix(typedCased);
      if (contraction.length > 0 && (this.driver.language === 0 || Driver.wordScore(true, typed) < 10)) {
        this.pendingText = contraction;
        this.pendingVi = false;
        this.hasPending = true;
        this.willCorrect = true;
      }
    }
    const comp = this.settings.suggestions ? Driver.completions(typed, vi, 6) : [];
    const cells: Suggestion[] = [];
    const shown = this.shownWord();
    const first = new Suggestion();
    first.text = shown;
    first.quoted = true;
    cells.push(first);
    const seen: string[] = [shown.toLowerCase()];
    if (this.willCorrect && this.hasPending && seen.indexOf(this.pendingText.toLowerCase()) < 0) {
      seen.push(this.pendingText.toLowerCase());
      const fix = new Suggestion();
      fix.text = this.pendingText;
      fix.highlighted = true;
      cells.push(fix);
    }
    if (this.settings.suggestions) {
      const accents = Driver.accentForms(typed, 3);
      for (let i = 0; i < accents.length && cells.length < 3; i++) {
        const label = this.cased(accents[i]);
        if (seen.indexOf(label.toLowerCase()) < 0) {
          seen.push(label.toLowerCase());
          const cell = new Suggestion();
          cell.text = label;
          cells.push(cell);
        }
      }
      let isWord = false;
      for (let i = 0; i < this.candidates.length; i++) {
        if (this.candidates[i].letters === typed) {
          isWord = true;
        }
      }
      const fixes: Candidate[] = [];
      for (let i = 0; i < this.candidates.length; i++) {
        if (this.candidates[i].score > -9) {
          fixes.push(this.candidates[i]);
        }
      }
      const ordered = isWord ? comp.concat(fixes) : fixes.concat(comp);
      for (let i = 0; i < ordered.length && cells.length < 3; i++) {
        const label = this.cased(ordered[i].text);
        if (seen.indexOf(label.toLowerCase()) < 0) {
          seen.push(label.toLowerCase());
          const cell = new Suggestion();
          cell.text = label;
          cells.push(cell);
        }
      }
    }
    if (cells.length === 1) {
      cells[0].quoted = false;
    }
    this.suggestions = (!this.settings.suggestions && !this.willCorrect) ? [] : cells;
  }

  private fillNextWords(): void {
    this.willCorrect = false;
    this.hasPending = false;
    const words = this.settings.suggestions ? nextWords.predict(this.lastContext) : [];
    const cells: Suggestion[] = [];
    for (let i = 0; i < words.length && cells.length < 3; i++) {
      const cell = new Suggestion();
      cell.text = words[i];
      cell.kind = 'next';
      cells.push(cell);
    }
    this.suggestions = cells;
  }

  private autoCorrectAtBreak(end: string): boolean {
    this.updateSuggestions();
    if (!this.willCorrect || !this.hasPending) {
      return false;
    }
    this.replaceWord(this.pendingText, this.pendingVi, true, end);
    return true;
  }

  private replaceWord(word: string, vietnamese: boolean, recordUndo: boolean, end: string): void {
    const old = this.shownWord();
    const insert = word + end;
    if (old.length > 0) {
      this.deleteBack(old.length);
    }
    if (this.target !== null) {
      this.target.insert(insert);
    }
    this.driver.resetContext();
    if ((this.driver.language === 1) !== vietnamese && this.driver.autoSwitch) {
      this.driver.language = vietnamese ? 1 : 0;
      this.settings.language = this.driver.language;
      if (this.persistLanguage !== null) {
        this.persistLanguage(this.driver.language);
      }
    }
    if (recordUndo) {
      const correction = new Correction();
      correction.typed = old;
      correction.inserted = insert;
      this.lastCorrection = correction;
    } else {
      this.lastCorrection = null;
    }
    this.lastSpace = end === ' ' ? this.now() : 0;
    this.clearWord();
    this.afterEdit(old.length, insert);
  }

  private undoCorrection(): boolean {
    const correction = this.lastCorrection;
    if (correction === null || !this.lastContext.endsWith(correction.inserted)) {
      this.lastCorrection = null;
      return false;
    }
    this.lastCorrection = null;
    this.deleteBack(correction.inserted.length);
    if (this.target !== null) {
      this.target.insert(correction.typed);
    }
    this.driver.resetContext();
    this.keepWord = correction.typed.toLowerCase();
    this.clearWord();
    this.afterEdit(correction.inserted.length, correction.typed);
    return true;
  }

  private snapsBack(text: string): boolean {
    if (text.length !== 1 || '.,?!")'.indexOf(text) < 0) {
      return false;
    }
    const before = this.lastContext;
    if (!before.endsWith(' ') || before.length < 2) {
      return false;
    }
    const previous = before.charAt(before.length - 2);
    if (previous === ' ' || previous === '\n') {
      return false;
    }
    const paraStart = before.lastIndexOf('\n');
    const para = paraStart < 0 ? before : before.substring(paraStart + 1);
    if (text === ')') {
      return this.countChar(para, '(') > this.countChar(para, ')');
    }
    if (text === '"') {
      return this.countChar(para, '"') % 2 === 1;
    }
    return true;
  }

  private updateAutoShift(before: string): void {
    if (this.layer !== 0 || this.shift === 2) {
      return;
    }
    if (!this.settings.autoCap) {
      if (this.shift === 1) {
        this.shift = 0;
      }
      return;
    }
    const trimmed = before.split(' ').join('');
    let start = before.length === 0 || before.endsWith('\n');
    let core = trimmed;
    while (core.length > 0 && '\"”’\')]'.indexOf(core.charAt(core.length - 1)) >= 0) {
      core = core.substring(0, core.length - 1);
    }
    if (!start && before.endsWith(' ') && core.length > 0) {
      const last = core.charAt(core.length - 1);
      start = last === '.' || last === '?' || last === '!' || last === '…';
    }
    this.shift = start ? 1 : 0;
  }

  private actionTitle(): string {
    if (this.multiline || this.enterKey === inputMethod.EnterKeyType.NEWLINE ||
      this.enterKey === inputMethod.EnterKeyType.UNSPECIFIED || this.enterKey === inputMethod.EnterKeyType.NONE) {
      return '';
    }
    if (this.enterKey === inputMethod.EnterKeyType.GO) { return 'ret_go'; }
    if (this.enterKey === inputMethod.EnterKeyType.SEARCH) { return 'ret_search'; }
    if (this.enterKey === inputMethod.EnterKeyType.SEND) { return 'ret_send'; }
    if (this.enterKey === inputMethod.EnterKeyType.DONE) { return 'ret_done'; }
    if (this.enterKey === inputMethod.EnterKeyType.NEXT || this.enterKey === inputMethod.EnterKeyType.PREVIOUS) {
      return 'ret_next';
    }
    return '';
  }

  private safeRead(): string {
    if (this.target === null) {
      return '';
    }
    try {
      return this.target.readBefore(2000);
    } catch (_e) {
      return '';
    }
  }

  private publish(): void {
    if (this.changed !== null) {
      this.changed();
    }
  }

  private now(): number {
    return Date.now() / 1000;
  }

  private isAsciiLetter(ch: string): boolean {
    const code = ch.charCodeAt(0);
    return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
  }

  private isLetter(ch: string): boolean {
    return ch.toLowerCase() !== ch.toUpperCase();
  }

  private isUpper(ch: string): boolean {
    return ch !== ch.toLowerCase() && ch === ch.toUpperCase();
  }

  private isLetterOrDigit(ch: string): boolean {
    return this.isLetter(ch) || (ch >= '0' && ch <= '9');
  }

  private lastGrapheme(text: string): number {
    if (text.length >= 2) {
      const lead = text.charCodeAt(text.length - 2);
      const tail = text.charCodeAt(text.length - 1);
      if (lead >= 0xD800 && lead <= 0xDBFF && tail >= 0xDC00 && tail <= 0xDFFF) {
        return 2;
      }
    }
    return 1;
  }

  onDocument(text: string): void {
    this.fullText = text;
    if (this.selBegin !== this.selEnd) {
      this.showSelection();
    }
  }

  onSelection(begin: number, end: number): void {
    this.selBegin = begin;
    this.selEnd = end;
    this.showSelection();
  }

  applyPreview(): void {
    this.replaceSelection(this.previewTo);
  }

  cancelPreview(): void {
    this.previewOn = false;
    if (this.selection.length > 0) {
      this.review = 'text';
      this.setNote('Sửa lỗi', 'proofread');
    } else {
      this.review = '';
      this.updateSuggestions();
    }
    this.publish();
  }

  private leaveSelection(): void {
    if (this.review.length === 0 && !this.previewOn) {
      return;
    }
    this.review = '';
    this.selection = '';
    this.previewOn = false;
    this.selBegin = this.selEnd;
  }

  private showSelection(): void {
    const start = this.selBegin < this.selEnd ? this.selBegin : this.selEnd;
    const end = this.selBegin > this.selEnd ? this.selBegin : this.selEnd;
    const count = end - start;
    if (count <= 0) {
      if (this.review === 'applied' && this.lastContext.endsWith(this.appliedInserted)) {
        this.previewOn = false;
        this.setNote('Hoàn tác', 'undo');
        this.publish();
        return;
      }
      if (this.review.length > 0 || this.previewOn) {
        this.review = '';
        this.selection = '';
        this.previewOn = false;
        this.updateSuggestions();
        this.publish();
      }
      return;
    }
    if (!this.correctsHere() || (!this.settings.suggestions && !this.settings.autoCorrect)) {
      return;
    }
    const raw = this.selectedText(start, end);
    const core = raw.trim();
    if (core.length === 0 || !this.hasLetter(core)) {
      this.review = '';
      this.selection = '';
      this.previewOn = false;
      this.updateSuggestions();
      this.publish();
      return;
    }
    this.selection = raw;
    this.previewOn = false;
    if (!this.hasSpace(core) && core.length <= 40) {
      this.review = 'word';
      const fixes = this.fixesFor(core);
      if (fixes.length === 0) {
        this.setNote('Không có lỗi ✓', 'busy');
      } else {
        const cells: Suggestion[] = [];
        for (let i = 0; i < fixes.length && cells.length < 3; i++) {
          const cell = new Suggestion();
          cell.text = fixes[i];
          cell.kind = 'alternative';
          cell.highlighted = i === 0;
          cells.push(cell);
        }
        this.suggestions = cells;
      }
    } else if (core.indexOf('\n') >= 0 || core.indexOf('\r') >= 0 || core.indexOf('  ') >= 0) {
      this.review = 'text';
      this.setNote('Hãy chọn trong một đoạn', 'busy');
    } else if (core.length > 1500) {
      this.review = 'text';
      this.setNote('Đoạn quá dài để sửa', 'busy');
    } else {
      this.review = 'text';
      this.setNote('Sửa lỗi', 'proofread');
    }
    this.publish();
  }

  private selectedText(start: number, end: number): string {
    const count = end - start;
    if (this.fullText.length >= end) {
      return this.fullText.substring(start, end);
    }
    const before = this.safeRead();
    if (before.length >= count) {
      return before.substring(before.length - count);
    }
    if (this.target !== null) {
      const after = this.target.readAfter(count);
      return after.substring(0, Math.min(count, after.length));
    }
    return '';
  }

  private runProofread(): void {
    const original = this.selection;
    if (this.review === 'word') {
      const fixes = this.fixesFor(original.trim());
      if (fixes.length === 0) {
        this.setNote('Không có lỗi ✓', 'busy');
      } else {
        this.replaceSelection(fixes[0]);
        return;
      }
      this.publish();
      return;
    }
    const fixed = this.proofreadText(original);
    if (fixed === original) {
      this.setNote('Không có lỗi ✓', 'busy');
      this.publish();
      return;
    }
    this.previewFrom = original;
    this.previewTo = fixed;
    this.previewOn = true;
    this.review = 'preview';
    this.suggestions = [];
    this.publish();
  }

  private proofreadText(text: string): string {
    let out = '';
    let word = '';
    let sentenceStart = true;
    for (let i = 0; i <= text.length; i++) {
      const ch = i < text.length ? text.charAt(i) : ' ';
      if (i < text.length && this.isLetter(ch)) {
        word += ch;
      } else {
        if (word.length > 0) {
          const fixes = this.fixesFor(word);
          let chosen = fixes.length > 0 ? fixes[0] : word;
          const lead = chosen.charAt(0);
          const wasCap = word.charAt(0) !== word.charAt(0).toLowerCase();
          if ((sentenceStart || wasCap) && lead !== lead.toUpperCase()) {
            chosen = lead.toUpperCase() + chosen.substring(1);
          }
          out += chosen;
          word = '';
          sentenceStart = false;
        }
        if (i < text.length) {
          out += ch;
          if (ch === '.' || ch === '!' || ch === '?' || ch === '\n') {
            sentenceStart = true;
          }
        }
      }
    }
    return out;
  }

  private fixesFor(word: string): string[] {
    const typed = word.toLowerCase();
    const out: string[] = [];
    const accents = Driver.accentForms(typed, 3);
    for (let i = 0; i < accents.length && out.length < 3; i++) {
      const label = this.matchCase(word, accents[i]);
      if (label.toLowerCase() !== typed && out.indexOf(label) < 0) {
        out.push(label);
      }
    }
    const vi = this.driver.language === 1;
    const list = Driver.candidates(typed, [], [], vi, this.letters, this.rects, 6);
    if (Driver.shouldCorrect(typed, list)) {
      for (let i = 0; i < list.length && out.length < 3; i++) {
        if (list[i].score <= -9) {
          continue;
        }
        const label = this.matchCase(word, list[i].text);
        if (label.toLowerCase() !== typed && out.indexOf(label) < 0) {
          out.push(label);
        }
      }
    }
    return out;
  }

  private replaceSelection(text: string): void {
    const original = this.selection.length > 0 ? this.selection : this.appliedOriginal;
    let before = this.safeRead();
    if (before.endsWith(original)) {
      before = before.substring(0, before.length - original.length);
      this.deleteBack(original.length);
    }
    if (this.target !== null && text.length > 0) {
      this.target.insert(text);
    }
    this.driver.resetContext();
    this.clearWord();
    this.lastContext = before + text;
    this.appliedOriginal = original;
    this.appliedInserted = text;
    this.selection = '';
    this.previewOn = false;
    this.review = 'applied';
    this.selBegin = this.selEnd;
    this.setNote('Hoàn tác', 'undo');
    this.publish();
  }

  private undoApplied(): void {
    if (!this.lastContext.endsWith(this.appliedInserted)) {
      this.review = '';
      this.updateSuggestions();
      this.publish();
      return;
    }
    const before = this.lastContext.substring(0, this.lastContext.length - this.appliedInserted.length);
    this.deleteBack(this.appliedInserted.length);
    if (this.target !== null && this.appliedOriginal.length > 0) {
      this.target.insert(this.appliedOriginal);
    }
    this.driver.resetContext();
    this.clearWord();
    this.lastContext = before + this.appliedOriginal;
    this.review = '';
    this.appliedInserted = '';
    this.updateSuggestions();
    this.publish();
  }

  private setNote(text: string, kind: string): void {
    const cell = new Suggestion();
    cell.text = text;
    cell.kind = kind;
    this.suggestions = [cell];
  }

  private matchCase(source: string, fix: string): string {
    if (source.length > 1 && source === source.toUpperCase()) {
      return fix.toUpperCase();
    }
    if (source.length > 0 && source.charAt(0) === source.charAt(0).toUpperCase() &&
      source.charAt(0) !== source.charAt(0).toLowerCase()) {
      return fix.substring(0, 1).toUpperCase() + fix.substring(1);
    }
    return fix;
  }

  private hasLetter(text: string): boolean {
    for (let i = 0; i < text.length; i++) {
      if (this.isLetter(text.charAt(i))) {
        return true;
      }
    }
    return false;
  }

  private hasSpace(text: string): boolean {
    for (let i = 0; i < text.length; i++) {
      const ch = text.charAt(i);
      if (ch === ' ' || ch === '\n' || ch === '\t') {
        return true;
      }
    }
    return false;
  }

  private countChar(text: string, ch: string): number {
    let n = 0;
    for (let i = 0; i < text.length; i++) {
      if (text.charAt(i) === ch) {
        n++;
      }
    }
    return n;
  }
}

export const typingSession: TypingSession = new TypingSession();
