import { common } from '@kit.AbilityKit';
import { util } from '@kit.ArkTS';

/** Next-word table from the iOS keyboard: "context<TAB>word<TAB>word<TAB>word", sorted by context. */
export class NextWords {
  private bytes: Uint8Array | null = null;

  bind(context: common.Context): void {
    if (this.bytes !== null) {
      return;
    }
    try {
      this.bytes = context.resourceManager.getRawFileContentSync('NextWords.tsv');
    } catch (_e) {
      this.bytes = new Uint8Array(0);
    }
  }

  predict(before: string): string[] {
    const words = this.lastWords(before);
    const out: string[] = [];
    if (words.length === 2) {
      this.take(out, this.lookup(words[0] + ' ' + words[1]));
    }
    if (words.length > 0 && out.length < 3) {
      this.take(out, this.lookup(words[words.length - 1]));
    }
    return out;
  }

  private take(out: string[], found: string[]): void {
    for (let i = 0; i < found.length && out.length < 3; i++) {
      if (out.indexOf(found[i]) < 0) {
        out.push(found[i]);
      }
    }
  }

  private lastWords(before: string): string[] {
    if (!before.endsWith(' ')) {
      return [];
    }
    const words: string[] = [];
    let cur = '';
    for (let i = before.length - 2; i >= 0; i--) {
      const ch = before.charAt(i);
      if (this.isLetter(ch)) {
        cur = ch + cur;
        continue;
      }
      if (cur.length > 0) {
        words.unshift(cur.toLowerCase());
        cur = '';
      }
      if (words.length === 2 || ch !== ' ') {
        break;
      }
    }
    if (cur.length > 0 && words.length < 2) {
      words.unshift(cur.toLowerCase());
    }
    return words.length > 2 ? words.slice(words.length - 2) : words;
  }

  private lookup(key: string): string[] {
    const data = this.bytes;
    if (data === null || data.length === 0 || key.length === 0) {
      return [];
    }
    const keyBytes = new util.TextEncoder().encodeInto(key);
    let lo = 0;
    let hi = data.length;
    while (lo < hi) {
      let start = (lo + hi) >> 1;
      while (start > lo && data[start - 1] !== 10) {
        start--;
      }
      const compared = this.compare(data, start, keyBytes);
      const end = this.lineEnd(data, start);
      if (compared === 0) {
        return this.wordsAfter(data, start, end);
      }
      if (compared < 0) {
        lo = end + 1;
      } else {
        hi = start;
      }
    }
    return [];
  }

  private compare(data: Uint8Array, start: number, key: Uint8Array): number {
    let i = start;
    let j = 0;
    while (i < data.length && data[i] !== 9 && data[i] !== 10 && j < key.length) {
      if (data[i] !== key[j]) {
        return data[i] < key[j] ? -1 : 1;
      }
      i++;
      j++;
    }
    const lineEnded = i >= data.length || data[i] === 9 || data[i] === 10;
    if (lineEnded && j === key.length) {
      return 0;
    }
    return lineEnded ? -1 : 1;
  }

  private lineEnd(data: Uint8Array, start: number): number {
    let end = start;
    while (end < data.length && data[end] !== 10) {
      end++;
    }
    return end;
  }

  private wordsAfter(data: Uint8Array, start: number, end: number): string[] {
    let i = start;
    while (i < end && data[i] !== 9) {
      i++;
    }
    if (i >= end) {
      return [];
    }
    const slice = data.subarray(i + 1, end);
    const rest = util.TextDecoder.create('utf-8').decodeToString(slice).replace('\r', '');
    const parts = rest.split('\t');
    const out: string[] = [];
    for (let p = 0; p < parts.length; p++) {
      if (parts[p].length > 0) {
        out.push(parts[p]);
      }
    }
    return out;
  }

  private isLetter(ch: string): boolean {
    const c = ch.charCodeAt(0);
    return (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c > 127;
  }
}

export const nextWords: NextWords = new NextWords();
