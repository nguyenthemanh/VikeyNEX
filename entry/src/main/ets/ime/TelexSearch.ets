/** A small Telex reader for emoji search ("nguwaj" to "ngựa"). */
export class TelexSearch {
  static convert(text: string): string {
    const parts = text.split(' ');
    let out = '';
    for (let i = 0; i < parts.length; i++) {
      if (i > 0) {
        out += ' ';
      }
      out += TelexSearch.word(parts[i]);
    }
    return out;
  }

  static word(keys: string): string {
    const out: string[] = [];
    let tone = 0;
    let toneKey = '';
    const lower = keys.toLowerCase();
    for (let i = 0; i < lower.length; i++) {
      const k = lower.charAt(i);
      const last = out.length > 0 ? out[out.length - 1] : '';
      if (k === 'd' && last === 'd') {
        out[out.length - 1] = 'đ';
      } else if (k === 'a' && last === 'a') {
        out[out.length - 1] = 'â';
      } else if (k === 'e' && last === 'e') {
        out[out.length - 1] = 'ê';
      } else if (k === 'o' && last === 'o') {
        out[out.length - 1] = 'ô';
      } else if (k === 'w') {
        TelexSearch.applyHorn(out);
      } else if (k === 'z') {
        tone = 0;
        toneKey = '';
      } else {
        const t = TelexSearch.toneOf(k);
        if (t > 0 && TelexSearch.hasVowel(out)) {
          if (toneKey === k) {
            tone = 0;
            toneKey = '';
            out.push(k);
          } else {
            tone = t;
            toneKey = k;
          }
        } else {
          out.push(k);
        }
      }
    }
    if (tone === 0) {
      return out.join('');
    }
    const index = TelexSearch.toneIndex(out);
    if (index < 0) {
      return out.join('');
    }
    const marked = TelexSearch.mark(out[index], tone);
    if (marked.length > 0) {
      out[index] = marked;
    }
    return out.join('');
  }

  private static toneOf(k: string): number {
    if (k === 's') { return 1; }
    if (k === 'f') { return 2; }
    if (k === 'r') { return 3; }
    if (k === 'x') { return 4; }
    if (k === 'j') { return 5; }
    return 0;
  }

  private static isVowel(c: string): boolean {
    return 'aăâeêioôơuưy'.indexOf(c) >= 0;
  }

  private static hasVowel(chars: string[]): boolean {
    for (let i = 0; i < chars.length; i++) {
      if (TelexSearch.isVowel(chars[i])) {
        return true;
      }
    }
    return false;
  }

  private static applyHorn(out: string[]): void {
    let i = out.length - 1;
    while (i >= 0 && 'aou'.indexOf(out[i]) < 0) {
      i--;
    }
    if (i >= 0) {
      const c = out[i];
      let blocked = false;
      for (let j = i + 1; j < out.length; j++) {
        if (TelexSearch.isVowel(out[j])) {
          blocked = true;
        }
      }
      if (!blocked || i === out.length - 1) {
        if (c === 'a') { out[i] = 'ă'; }
        else if (c === 'o') { out[i] = 'ơ'; }
        else { out[i] = 'ư'; }
        if (c === 'o' && i > 0 && out[i - 1] === 'u') { out[i - 1] = 'ư'; }
        if (c === 'u' && i + 1 < out.length && out[i + 1] === 'o') { out[i + 1] = 'ơ'; }
        return;
      }
    }
    out.push('ư');
  }

  private static mark(base: string, tone: number): string {
    const forms: string[] = [];
    if (base === 'a') { forms.push('á', 'à', 'ả', 'ã', 'ạ'); }
    else if (base === 'ă') { forms.push('ắ', 'ằ', 'ẳ', 'ẵ', 'ặ'); }
    else if (base === 'â') { forms.push('ấ', 'ầ', 'ẩ', 'ẫ', 'ậ'); }
    else if (base === 'e') { forms.push('é', 'è', 'ẻ', 'ẽ', 'ẹ'); }
    else if (base === 'ê') { forms.push('ế', 'ề', 'ể', 'ễ', 'ệ'); }
    else if (base === 'i') { forms.push('í', 'ì', 'ỉ', 'ĩ', 'ị'); }
    else if (base === 'o') { forms.push('ó', 'ò', 'ỏ', 'õ', 'ọ'); }
    else if (base === 'ô') { forms.push('ố', 'ồ', 'ổ', 'ỗ', 'ộ'); }
    else if (base === 'ơ') { forms.push('ớ', 'ờ', 'ở', 'ỡ', 'ợ'); }
    else if (base === 'u') { forms.push('ú', 'ù', 'ủ', 'ũ', 'ụ'); }
    else if (base === 'ư') { forms.push('ứ', 'ừ', 'ử', 'ữ', 'ự'); }
    else if (base === 'y') { forms.push('ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ'); }
    if (tone < 1 || tone > forms.length) {
      return '';
    }
    return forms[tone - 1];
  }

  private static toneIndex(w: string[]): number {
    let start = 0;
    if (w.length > 2 && w[0] === 'q' && w[1] === 'u') { start = 2; }
    else if (w.length > 2 && w[0] === 'g' && w[1] === 'i' && TelexSearch.isVowel(w[2])) { start = 2; }
    const idx: number[] = [];
    for (let i = start; i < w.length; i++) {
      if (TelexSearch.isVowel(w[i])) { idx.push(i); }
    }
    if (idx.length === 0) { return -1; }
    const nucleus: number[] = [];
    let j = idx[0];
    while (idx.indexOf(j) >= 0) {
      nucleus.push(j);
      j++;
    }
    for (let n = nucleus.length - 1; n >= 0; n--) {
      if ('ăâêôơư'.indexOf(w[nucleus[n]]) >= 0) { return nucleus[n]; }
    }
    if (nucleus.length === 1) { return idx[0]; }
    const endsInConsonant = idx[idx.length - 1] < w.length - 1;
    if (endsInConsonant || nucleus.length === 3) { return nucleus[1]; }
    const pair = w[nucleus[0]] + w[nucleus[1]];
    if (pair === 'oa' || pair === 'oe' || pair === 'uy') { return nucleus[1]; }
    return nucleus[0];
  }
}
