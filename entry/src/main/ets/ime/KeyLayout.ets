export class KeyCell {
  id: string = '';
  kind: string = '';
  text: string = '';
  label: string = '';
  x: number = 0;
  y: number = 0;
  w: number = 0;
  h: number = 0;
  special: boolean = false;
}

export class KeyLayout {
  static height(compact: boolean, bar: boolean): number {
    const keyH = compact ? 34 : 43;
    const pitch = compact ? 40 : 54;
    const bottom = compact ? 4 : 3;
    const extra = bar ? 44 : 0;
    const top = compact ? 8 + extra : 11 + extra - (bar ? 3 : 0);
    return top + 3 * pitch + keyH + bottom;
  }

  static build(width: number, compact: boolean, bar: boolean, layer: number, shift: number, lang: string,
    returnLabel: string, globe: boolean, langInBar: boolean): KeyCell[] {
    const keyH = compact ? 34 : 43;
    const pitch = compact ? 40 : 54;
    const extra = bar ? 44 : 0;
    const top = compact ? 8 + extra : 11 + extra - (bar ? 3 : 0);
    const side = 6.67;
    const gap = 6;
    const keyW = (width - 2 * side - 9 * gap) / 10;
    const span = (width - 402) / 38;
    const fn = 45.5 + span * (50.17 - 45.5);
    const small = 43.33 + span * (48 - 43.33);
    const ret = 93 + span * (102.33 - 93);
    const rows = KeyLayout.rows(layer, globe, langInBar);
    const cells: KeyCell[] = [];
    for (let r = 0; r < rows.length; r++) {
      const row = rows[r];
      const y = top + r * pitch;
      if (r === 0 || r === 1) {
        const x0 = r === 1 && row.length === 9 ? side + (keyW + gap) / 2 : side;
        for (let i = 0; i < row.length; i++) {
          KeyLayout.place(cells, row[i], r, i, x0 + i * (keyW + gap), y, keyW, keyH, shift, lang, returnLabel);
        }
      } else if (r === 2) {
        KeyLayout.place(cells, row[0], r, 0, side, y, fn, keyH, shift, lang, returnLabel);
        const inner = row.length - 2;
        if (inner === 7) {
          const x0 = side + (keyW + gap) * 1.5;
          for (let i = 0; i < inner; i++) {
            KeyLayout.place(cells, row[i + 1], r, i + 1, x0 + i * (keyW + gap), y, keyW, keyH, shift, lang, returnLabel);
          }
        } else {
          const left = side + fn + gap * 2.5;
          const right = width - side - fn - gap * 2.5;
          const w = (right - left - (inner - 1) * gap) / inner;
          for (let i = 0; i < inner; i++) {
            KeyLayout.place(cells, row[i + 1], r, i + 1, left + i * (w + gap), y, w, keyH, shift, lang, returnLabel);
          }
        }
        KeyLayout.place(cells, row[row.length - 1], r, row.length - 1, width - side - fn, y, fn, keyH, shift, lang,
          returnLabel);
      } else {
        let charKeys = 0;
        let fixed = 0;
        let hasSpace = false;
        for (let i = 0; i < row.length; i++) {
          if (row[i] === 'space') {
            hasSpace = true;
          } else if (row[i] === 'return') {
            continue;
          } else if (row[i].length === 1) {
            charKeys++;
          } else {
            fixed++;
          }
        }
        const charW = hasSpace ? small :
          (width - 2 * side - ret - fixed * (small + gap) - charKeys * gap) / Math.max(1, charKeys);
        let x = side;
        for (let i = 0; i < row.length; i++) {
          const token = row[i];
          if (token === 'return') {
            KeyLayout.place(cells, token, r, i, width - side - ret, y, ret, keyH, shift, lang, returnLabel);
          } else if (token === 'space') {
            const after = charKeys * (small + gap);
            const w = width - side - ret - gap - x - after;
            KeyLayout.place(cells, token, r, i, x, y, w, keyH, shift, lang, returnLabel);
            x += w + gap;
          } else if (token.length === 1) {
            KeyLayout.place(cells, token, r, i, x, y, charW, keyH, shift, lang, returnLabel);
            x += charW + gap;
          } else {
            KeyLayout.place(cells, token, r, i, x, y, small, keyH, shift, lang, returnLabel);
            x += small + gap;
          }
        }
      }
    }
    return cells;
  }

  private static place(cells: KeyCell[], token: string, row: number, index: number, x: number, y: number,
    w: number, h: number, shift: number, lang: string, returnLabel: string): void {
    const cell = KeyLayout.cell(token, shift, lang, returnLabel);
    cell.x = x;
    cell.y = y;
    cell.w = w;
    cell.h = h;
    cell.id = row + ':' + index + ':' + cell.kind + ':' + cell.text;
    cells.push(cell);
  }

  static letterGeometry(cells: KeyCell[]): string[] {
    let letters = '';
    const rects: number[] = [];
    for (let i = 0; i < cells.length; i++) {
      const cell = cells[i];
      if (cell.kind === 'char' && cell.text.length === 1 && cell.text >= 'a' && cell.text <= 'z') {
        letters += cell.text;
        rects.push(cell.x, cell.y, cell.w, cell.h);
      }
    }
    return [letters, rects.join(',')];
  }

  private static rows(layer: number, globe: boolean, langInBar: boolean): string[][] {
    const bottom: string[] = ['layer', 'emoji', 'space', 'return'];
    void globe;
    void langInBar;
    if (layer === 1) {
      return [['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
        ['-', '/', ':', ';', '(', ')', '$', '&', '@', '"'],
        ['#sym', '.', ',', '?', '!', "'", 'back'], bottom];
    }
    if (layer === 2) {
      return [['[', ']', '{', '}', '#', '%', '^', '*', '+', '='],
        ['_', '\\', '|', '~', '<', '>', '€', '£', '¥', '•'],
        ['#num', '.', ',', '?', '!', "'", 'back'], bottom];
    }
    return [['q', 'w', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['a', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l'],
      ['shift', 'z', 'x', 'c', 'v', 'b', 'n', 'm', 'back'], bottom];
  }

  private static cell(token: string, shift: number, lang: string, returnLabel: string): KeyCell {
    const cell = new KeyCell();
    if (token === 'shift') {
      cell.kind = 'shift';
      cell.label = shift === 2 ? '⇪' : '⇧';
      cell.special = true;
    } else if (token === 'back') {
      cell.kind = 'back';
      cell.label = '⌫';
      cell.special = true;
    } else if (token === 'space') {
      cell.kind = 'space';
      cell.label = '';
    } else if (token === 'return') {
      cell.kind = 'return';
      cell.label = returnLabel.length > 0 ? returnLabel : '⏎';
      cell.special = returnLabel.length > 0;
    } else if (token === 'lang') {
      cell.kind = 'lang';
      cell.label = lang;
      cell.special = true;
    } else if (token === 'emoji') {
      cell.kind = 'emoji';
      cell.label = '☺';
      cell.special = true;
    } else if (token === 'globe') {
      cell.kind = 'globe';
      cell.label = '🌐';
      cell.special = true;
    } else if (token === 'layer') {
      cell.kind = 'layer';
      cell.label = '123';
      cell.special = true;
    } else if (token === '#sym') {
      cell.kind = 'layer';
      cell.text = '2';
      cell.label = '#+=';
      cell.special = true;
    } else if (token === '#num') {
      cell.kind = 'layer';
      cell.text = '1';
      cell.label = '123';
      cell.special = true;
    } else {
      cell.kind = 'char';
      cell.text = token;
      cell.label = shift !== 0 && token >= 'a' && token <= 'z' ? token.toUpperCase() : token;
    }
    return cell;
  }
}

export function alternatesFor(text: string, upper: boolean): string[] {
  let list: string[] = [];
  if (text === 'a') { list = ['a', 'ă', 'â', 'á', 'à', 'ả', 'ã', 'ạ']; }
  else if (text === 'e') { list = ['e', 'ê', 'é', 'è', 'ẻ', 'ẽ', 'ẹ']; }
  else if (text === 'o') { list = ['o', 'ô', 'ơ', 'ó', 'ò', 'ỏ', 'õ', 'ọ']; }
  else if (text === 'u') { list = ['u', 'ư', 'ú', 'ù', 'ủ', 'ũ', 'ụ']; }
  else if (text === 'i') { list = ['i', 'í', 'ì', 'ỉ', 'ĩ', 'ị']; }
  else if (text === 'y') { list = ['y', 'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ']; }
  else if (text === 'd') { list = ['d', 'đ']; }
  else if (text === '.') { list = ['.', '…']; }
  else if (text === '-') { list = ['-', '–', '—', '•']; }
  else if (text === "'") { list = ["'", '’', '‘', '`']; }
  else if (text === '"') { list = ['"', '“', '”', '„', '«', '»']; }
  else if (text === '!') { list = ['!', '¡']; }
  else if (text === '?') { list = ['?', '¿']; }
  else if (text === '$') { list = ['$', '₫', '€', '£', '¥', '₩', '¢']; }
  else if (text === '0') { list = ['0', '°']; }
  else if (text === '&') { list = ['&', '§']; }
  else if (text === '/') { list = ['/', '\\']; }
  else if (text === '%') { list = ['%', '‰']; }
  if (!upper) {
    return list;
  }
  const out: string[] = [];
  for (let i = 0; i < list.length; i++) {
    out.push(list[i].toUpperCase());
  }
  return out;
}
