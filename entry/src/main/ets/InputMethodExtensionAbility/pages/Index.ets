import { Suggestion, typingSession } from '../../ime/TypingSession';
import { Driver } from '../../ime/Driver';
import { KeyCell, KeyLayout, alternatesFor } from '../../ime/KeyLayout';
import { EmojiCategory, EmojiModel, emojiModel } from '../../ime/EmojiModel';
import { TelexSearch } from '../../ime/TelexSearch';
import { keyboardController } from '../model/KeyboardController';

class TouchTrack {
  id: number = 0;
  downX: number = 0;
  downY: number = 0;
  x: number = 0;
  y: number = 0;
  active: KeyCell | null = null;
  slide: boolean = false;
  cursor: boolean = false;
  cursorAnchor: number = 0;
  hold: number = -1;
  repeat: number = -1;
  repeatCount: number = 0;
  barIndex: number = -1;
  searchIndex: number = -1;
  showingAlts: boolean = false;
}

@Entry
@Component
struct KeyboardPage {
  @StorageLink('kbTick') @Watch('onTick') tick: number = 0;
  @StorageLink('kbDark') night: boolean = false;
  @StorageLink('imeMenu') menu: boolean = false;
  @StorageLink('kbInset') inset: number = 0;
  @State boardWidth: number = 360;
  @State boardHeight: number = 0;
  @State cells: KeyCell[] = [];
  @State pressed: string = '';
  @State popup: string = '';
  @State popupX: number = 0;
  @State alts: string[] = [];
  @State altIndex: number = 0;
  @State altX: number = 0;
  @State altY: number = 0;
  @State barItems: Suggestion[] = [];
  @State langMark: string = 'VI';
  @State showPreview: boolean = false;
  @State previewFrom: string = '';
  @State previewTo: string = '';
  @State emojiOn: boolean = false;
  @State emojiCells: string[] = [];
  @State emojiGroup: number = -1;
  @State emojiSearch: boolean = false;
  @State emojiQuery: string = '';
  @State emojiResults: string[] = [];
  private emojiScroller: Scroller = new Scroller();
  private emojiScroll: number = 0;
  private emojiMoved: boolean = false;
  private resultScroll: number = 0;
  private tracks: TouchTrack[] = [];
  private active: KeyCell | null = null;
  private downX: number = 0;
  private downY: number = 0;
  private layoutKey: string = '';
  private letterKey: string = '';
  private letterRects: number[] = [];

  aboutToAppear(): void {
    keyboardController.syncChrome();
    this.syncBar();
    this.relayout();
  }

  onTick(): void {
    this.syncBar();
    this.relayout();
    keyboardController.applySearchPanel(emojiModel.searching);
  }

  private syncBar(): void {
    this.barItems = typingSession.suggestions;
    this.langMark = typingSession.driver.language === 1 ? 'VI' : 'EN';
    this.showPreview = typingSession.previewOn;
    this.previewFrom = typingSession.previewFrom;
    this.previewTo = typingSession.previewTo;
    this.emojiSearch = emojiModel.open && emojiModel.searching;
    this.emojiOn = emojiModel.open && !emojiModel.searching;
    this.emojiGroup = emojiModel.group;
    this.emojiQuery = emojiModel.query;
    if (this.emojiSearch) {
      emojiModel.refresh();
    }
    const cells: string[] = [];
    for (let i = 0; i < emojiModel.cells.length; i++) {
      cells.push(emojiModel.cells[i]);
    }
    if (this.emojiSearch) {
      this.emojiResults = cells;
    } else {
      this.emojiCells = cells;
    }
  }

  build() {
    Stack() {
      Column() {
        if (this.emojiOn) {
          this.emojiHeader()
          this.emojiGrid()
        } else {
          if (this.emojiSearch) {
            this.searchStrip()
          } else if (typingSession.settings.suggestions || typingSession.settings.autoCorrect) {
            this.suggestionBar()
          }
          this.keyLayer()
        }
      }
      .width('100%')
      .height('100%')
      .linearGradient({
        angle: 180,
        colors: [[this.boardTop(), 0], [this.boardBottom(), 1]]
      })

      Row()
        .width('100%')
        .height(1)
        .backgroundColor(this.night ? '#40FFFFFF' : '#CCFFFFFF')
        .hitTestBehavior(HitTestMode.None)
        .position({ x: 0, y: 0 })

      if (this.popup.length > 0) {
        Text(this.popup)
          .width(this.activeWidth())
          .height(54)
          .fontSize(28)
          .fontColor(this.ink())
          .textAlign(TextAlign.Center)
          .linearGradient({
            angle: 180,
            colors: [[this.night ? '#9A9AA2' : '#FFFFFF', 0], [this.night ? '#6A6A72' : '#F3F4F8', 1]]
          })
          .borderRadius(14)
          .border({ width: 0.6, color: this.night ? '#55FFFFFF' : '#FFFFFF' })
          .shadow({ radius: 12, color: this.night ? '#66000000' : '#29000000', offsetX: 0, offsetY: 3 })
          .position({ x: this.popupX, y: 2 })
      }
      if (this.alts.length > 0) {
        Row() {
          ForEach(this.alts, (item: string, index: number) => {
            Text(item)
              .width(34)
              .height(44)
              .fontSize(22)
              .textAlign(TextAlign.Center)
              .fontColor(index === this.altIndex ? Color.White : this.ink())
              .backgroundColor(index === this.altIndex ? this.accent() : Color.Transparent)
              .borderRadius(10)
          }, (item: string, index: number) => item + index)
        }
        .padding(4)
        .linearGradient({
          angle: 180,
          colors: [[this.night ? '#3A3A40' : '#FFFFFF', 0], [this.night ? '#2A2A2E' : '#F4F5F8', 1]]
        })
        .borderRadius(16)
        .border({ width: 0.6, color: this.night ? '#33FFFFFF' : '#FFFFFF' })
        .shadow({ radius: 16, color: this.night ? '#80000000' : '#33000000', offsetX: 0, offsetY: 4 })
        .position({ x: this.altX, y: this.altY })
      }
      if (this.menu) {
        this.imeMenu()
      }
      if (this.showPreview) {
        this.proofreadPreview()
      }
    }
    .width('100%')
    .height('100%')
    .onAreaChange((_old, area) => {
      const next = area.width as number;
      const nextH = area.height as number;
      const widthChanged = next > 0 && Math.abs(next - this.boardWidth) > 1;
      const heightChanged = nextH > 0 && Math.abs(nextH - this.boardHeight) > 1;
      if (widthChanged) {
        this.boardWidth = next;
      }
      if (heightChanged) {
        this.boardHeight = nextH;
      }
      if (widthChanged || heightChanged) {
        this.relayout();
      }
    })
    .onTouch((event: TouchEvent) => {
      this.handleTouch(event);
    })
  }

  @Builder
  proofreadPreview() {
    Column() {
      Text('BẢN ĐÃ SỬA')
        .fontSize(13)
        .fontColor(this.accent())
        .fontWeight(FontWeight.Bold)
        .width('100%')
        .margin({ bottom: 8 })
      Text(this.previewFrom)
        .fontSize(16)
        .fontColor(this.muted())
        .width('100%')
        .maxLines(3)
        .decoration({ type: TextDecorationType.LineThrough, color: this.muted() })
      Text(this.previewTo)
        .fontSize(18)
        .fontColor(this.ink())
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .maxLines(4)
        .margin({ top: 8, bottom: 16 })
      Row() {
        Button('Hủy')
          .layoutWeight(1)
          .height(40)
          .fontSize(16)
          .backgroundColor(this.night ? '#3A3A40' : '#E5E5EA')
          .fontColor(this.ink())
          .onClick(() => { typingSession.cancelPreview(); })
        Button('Áp dụng')
          .layoutWeight(1)
          .height(40)
          .fontSize(16)
          .backgroundColor(this.accent())
          .fontColor(Color.White)
          .margin({ left: 8 })
          .onClick(() => { typingSession.applyPreview(); })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(16)
    .backgroundColor(this.night ? '#1C1C1E' : '#F2F2F7')
    .justifyContent(FlexAlign.Center)
  }

  private suggestionColor(item: Suggestion): ResourceColor {
    if (item.kind === 'proofread' || item.kind === 'undo') {
      return this.accent();
    }
    if (item.kind === 'busy') {
      return this.muted();
    }
    return this.ink();
  }

  @Builder
  suggestionBar() {
    Row() {
      Text(this.langMark)
        .width(50)
        .height(38)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.accent())
        .textAlign(TextAlign.Center)
        .backgroundColor(this.night ? '#3A3A40' : '#FFFFFF')
        .border({ width: 0.5, color: this.night ? '#33FFFFFF' : '#FFFFFF' })
        .borderRadius(19)
        .margin({ left: 7, right: 8 })
      if (this.barItems.length > 0) {
        ForEach(this.barItems, (item: Suggestion, index: number) => {
          Text(item.quoted ? '\u201C' + item.text + '\u201D' : item.text)
            .layoutWeight(1)
            .height(36)
            .fontSize(17)
            .fontWeight(item.highlighted || item.kind === 'proofread' ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.suggestionColor(item))
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .backgroundColor(item.highlighted ? (this.night ? '#5C5C64' : '#FFFFFF') : Color.Transparent)
            .borderRadius(10)
        }, (item: Suggestion, index: number) => item.kind + item.text + index)
      } else {
        Blank()
      }
      if (this.showHideKey()) {
        this.hideKey()
      }
    }
    .width('100%')
    .height(44)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  searchStrip() {
    Column() {
      Text(this.emojiQuery.length > 0 ? this.shownQuery() : 'Tìm emoji')
        .width('100%')
        .height(28)
        .fontSize(16)
        .fontColor(this.emojiQuery.length > 0 ? this.ink() : this.muted())
        .padding({ left: 12 })
        .backgroundColor(this.night ? '#2C2C30' : '#FFFFFF')
      Scroll() {
        Row() {
          ForEach(this.emojiResults, (item: string, index: number) => {
            Text(item)
              .width(44)
              .height(44)
              .fontSize(26)
              .textAlign(TextAlign.Center)
          }, (item: string, index: number) => item + index)
        }
        .height(44)
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')
      .height(44)
      .onScroll((x: number, _y: number) => {
        this.resultScroll = x;
      })
    }
    .width('100%')
    .height(72)
  }

  @Builder
  hideKey() {
    Column() {
      Column() {
        Row() {
          this.hidePip()
          this.hidePip()
          this.hidePip()
        }
        .width(16)
        .justifyContent(FlexAlign.SpaceBetween)
        Row() {
          this.hidePip()
          this.hidePip()
          this.hidePip()
        }
        .width(16)
        .justifyContent(FlexAlign.SpaceBetween)
        .margin({ top: 2 })
        Row()
          .width(10)
          .height(2)
          .backgroundColor(this.ink())
          .borderRadius(1)
          .margin({ top: 2 })
      }
      .width(22)
      .height(16)
      .justifyContent(FlexAlign.Center)
      .border({ width: 1.2, color: this.ink() })
      .borderRadius(3)
      Polygon()
        .width(7)
        .height(4)
        .points([[0, 0], [7, 0], [3.5, 4]])
        .fill(this.ink())
        .margin({ top: 2 })
    }
    .width(36)
    .height(34)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.night ? '#5C5C64' : '#FFFFFF')
    .border({ width: 0.5, color: this.night ? '#33FFFFFF' : '#FFFFFF' })
    .borderRadius(10)
    .margin({ right: 8 })
  }

  @Builder
  hidePip() {
    Row()
      .width(3.5)
      .height(2)
      .backgroundColor(this.ink())
      .borderRadius(0.5)
  }

  private showHideKey(): boolean {
    for (let i = 0; i < this.barItems.length; i++) {
      if (this.barItems[i].kind !== 'next') {
        return false;
      }
    }
    return true;
  }

  private hideSlot(): number {
    return this.showHideKey() ? 48 : 0;
  }

  private shownQuery(): string {
    if (typingSession.driver.language === 1) {
      return TelexSearch.convert(this.emojiQuery);
    }
    return this.emojiQuery;
  }

  @Builder
  keyLayer() {
    Stack() {
      ForEach(this.cells, (cell: KeyCell) => {
        Text(cell.label)
          .width(cell.w)
          .height(cell.h)
          .fontSize(cell.kind === 'char' ? 23 : 16)
          .fontWeight(cell.kind === 'lang' ? FontWeight.Bold : FontWeight.Medium)
          .textAlign(TextAlign.Center)
          .fontColor(this.keyInk(cell))
          .linearGradient({
            angle: 175,
            colors: [[this.keyTop(cell), 0], [this.keyBottom(cell), 1]]
          })
          .border({ width: 0.6, color: this.keyStroke(cell) })
          .borderRadius(9)
          .shadow({
            radius: 3,
            color: this.night ? '#59000000' : '#1A000000',
            offsetX: 0,
            offsetY: 1
          })
          .position({ x: cell.x, y: cell.y })
      }, (cell: KeyCell) => cell.id)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  emojiHeader() {
    Row() {
      Text('ABC').fontSize(16).width(52).height(40).textAlign(TextAlign.Center).fontColor(this.ink())
      Text('🔍').fontSize(18).width(44).height(40).textAlign(TextAlign.Center)
      Text(this.toneLabel()).fontSize(16).layoutWeight(1).textAlign(TextAlign.Center)
      Text('⌫').fontSize(18).width(48).height(40).textAlign(TextAlign.Center).fontColor(this.ink())
    }
    .width('100%')
    .height(40)
    Row() {
      ForEach(this.categories(), (cat: EmojiCategory, index: number) => {
        Text(cat.icon)
          .fontSize(18)
          .layoutWeight(1)
          .height(32)
          .maxLines(1)
          .textAlign(TextAlign.Center)
          .fontColor(this.emojiGroup === cat.group ? this.accent() : this.ink())
      }, (cat: EmojiCategory, index: number) => cat.icon + index)
    }
    .width('100%')
    .height(32)
  }

  @Builder
  emojiGrid() {
    if (this.emojiCells.length === 0) {
      Text('Chưa có emoji')
        .width('100%')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
        .fontColor(this.muted())
    } else {
      Scroll(this.emojiScroller) {
        Column() {
          ForEach(this.emojiLines(), (line: string[], row: number) => {
            Row() {
              ForEach(line, (item: string, col: number) => {
                Text(item)
                  .width(this.boardWidth / this.emojiColumns())
                  .height(44)
                  .fontSize(this.emojiGroup === -2 ? 15 : 26)
                  .maxLines(1)
                  .textAlign(TextAlign.Center)
              }, (item: string, col: number) => this.emojiGroup + ':' + row + ':' + col + ':' + item)
            }
            .width('100%')
            .height(44)
          }, (line: string[], row: number) => this.emojiGroup + ':' + row + ':' + line[0])
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
      .onScroll((_x: number, y: number) => {
        this.emojiScroll = y;
      })
    }
  }

  @Builder
  imeMenu() {
    Column() {
      ForEach(keyboardController.imeNames(), (item: string, index: number) => {
        Text(item)
          .width('100%')
          .height(44)
          .fontSize(16)
          .fontColor(this.ink())
          .textAlign(TextAlign.Center)
          .onClick(() => keyboardController.pickIme(index))
      }, (item: string, index: number) => item + index)
      Text('Đóng').width('100%').height(40).textAlign(TextAlign.Center).fontColor(this.accent())
        .onClick(() => keyboardController.hideMenu())
    }
    .width('70%')
    .linearGradient({
      angle: 180,
      colors: [[this.night ? '#3A3A40' : '#FFFFFF', 0], [this.night ? '#2A2A2E' : '#F4F5F8', 1]]
    })
    .border({ width: 0.6, color: this.night ? '#33FFFFFF' : '#FFFFFF' })
    .borderRadius(16)
    .shadow({ radius: 18, color: '#66000000', offsetX: 0, offsetY: 6 })
    .position({ x: '15%', y: 48 })
  }

  private categories(): EmojiCategory[] {
    return EmojiModel.categories();
  }

  private emojiColumns(): number {
    return this.emojiGroup === -2 ? 2 : 8;
  }

  private emojiLines(): string[][] {
    const columns = this.emojiColumns();
    const lines: string[][] = [];
    let row: string[] = [];
    for (let i = 0; i < this.emojiCells.length; i++) {
      row.push(this.emojiCells[i]);
      if (row.length === columns) {
        lines.push(row);
        row = [];
      }
    }
    if (row.length > 0) {
      lines.push(row);
    }
    return lines;
  }

  private emojiTap(x: number, y: number): void {
    if (y < 40) {
      if (x < 52) {
        emojiModel.open = false;
        emojiModel.searching = false;
        this.emojiScroll = 0;
        this.relayout();
      } else if (x < 96) {
        emojiModel.searching = true;
        emojiModel.query = '';
        this.relayout();
      } else if (x > this.boardWidth - 48) {
        typingSession.onBackspace();
      } else {
        emojiModel.tone = (emojiModel.tone + 1) % 6;
        emojiModel.refresh();
      }
      this.bump();
      return;
    }
    if (y < 72) {
      const cats = this.categories();
      const index = Math.min(cats.length - 1, Math.max(0, Math.floor(x / (this.boardWidth / cats.length))));
      emojiModel.group = cats[index].group;
      emojiModel.refresh();
      this.emojiGroup = emojiModel.group;
      const shown: string[] = [];
      for (let i = 0; i < emojiModel.cells.length; i++) {
        shown.push(emojiModel.cells[i]);
      }
      this.emojiCells = shown;
      this.emojiScroll = 0;
      this.emojiScroller.scrollTo({ xOffset: 0, yOffset: 0 });
      this.bump();
      return;
    }
    const columns = this.emojiColumns();
    const col = Math.min(columns - 1, Math.max(0, Math.floor(x / (this.boardWidth / columns))));
    const row = Math.floor((y - 72 + this.emojiScroll) / 44);
    const index = row * columns + col;
    if (index < 0 || index >= this.emojiCells.length) {
      return;
    }
    const item = this.emojiCells[index];
    emojiModel.record(item);
    typingSession.insertPlain(item);
  }

  private toneLabel(): string {
    const tones = ['👋', '👋🏻', '👋🏼', '👋🏽', '👋🏾', '👋🏿'];
    return tones[emojiModel.tone];
  }

  private ink(): string {
    return this.night ? '#F5F5F7' : '#1C1C1E';
  }

  private muted(): string {
    return this.night ? '#AEAEB2' : '#8E8E93';
  }

  private accent(): string {
    return this.night ? '#0A84FF' : '#007AFF';
  }

  private boardTop(): string {
    return this.night ? '#2E2E33' : '#F3F4F8';
  }

  private boardBottom(): string {
    return this.night ? '#141416' : '#D5D8E0';
  }

  private keyTop(cell: KeyCell): string {
    const down = this.pressed === cell.id;
    if (cell.kind === 'return' && typingSession.returnBlue) {
      return this.night ? (down ? '#8EC5FF' : '#6CB6FF') : (down ? '#8EC2FF' : '#5AADFF');
    }
    if (this.night) {
      if (down) {
        return cell.special ? '#6E6E76' : '#C6C6CE';
      }
      return cell.special ? '#5A5A62' : '#9C9CA4';
    }
    if (down) {
      return cell.special ? '#D8DCE4' : '#FFFFFF';
    }
    return cell.special ? '#F0F1F6' : '#FFFFFF';
  }

  private keyBottom(cell: KeyCell): string {
    const down = this.pressed === cell.id;
    if (cell.kind === 'return' && typingSession.returnBlue) {
      return this.night ? (down ? '#409CFF' : '#0A84FF') : (down ? '#3395FF' : '#007AFF');
    }
    if (this.night) {
      if (down) {
        return cell.special ? '#52525A' : '#909098';
      }
      return cell.special ? '#38383E' : '#5E5E66';
    }
    if (down) {
      return cell.special ? '#C4C8D2' : '#E4E6ED';
    }
    return cell.special ? '#C6CBD4' : '#F4F5F9';
  }

  private keyStroke(cell: KeyCell): string {
    if (cell.kind === 'return' && typingSession.returnBlue) {
      return '#73FFFFFF';
    }
    if (this.night) {
      return cell.special ? '#2EFFFFFF' : '#59FFFFFF';
    }
    return '#F2FFFFFF';
  }

  private keyInk(cell: KeyCell): string {
    if (cell.kind === 'return' && typingSession.returnBlue) {
      return '#FFFFFF';
    }
    return this.ink();
  }

  private activeWidth(): number {
    return this.active === null ? 36 : this.active.w;
  }

  private relayout(): void {
    const compact = this.boardHeight > 0 && this.boardHeight < 200;
    const lang = typingSession.driver.language === 1 ? 'VI' : 'EN';
    const title = this.returnText();
    const key = Math.round(this.boardWidth) + ':' + (compact ? '1' : '0') + ':' + lang + ':' + title + ':' +
      typingSession.layer + ':' + typingSession.shift + ':' + (typingSession.showsGlobe ? '1' : '0') + ':' +
      (this.barOn() ? '1' : '0') + ':' + (emojiModel.searching ? '1' : '0');
    if (key === this.layoutKey && this.cells.length > 0) {
      return;
    }
    this.layoutKey = key;
    this.cells = KeyLayout.build(this.boardWidth, compact, false, typingSession.layer, typingSession.shift, lang, title,
      typingSession.showsGlobe, this.barOn());
    const geo = KeyLayout.letterGeometry(this.cells);
    const parts = geo[1].split(',');
    const rects: number[] = [];
    for (let i = 0; i < parts.length; i++) {
      if (parts[i].length > 0) {
        rects.push(Number.parseFloat(parts[i]));
      }
    }
    this.letterKey = geo[0];
    this.letterRects = rects;
    typingSession.setGeometry(geo[0], rects);
  }

  private barOn(): boolean {
    if (emojiModel.open) {
      return false;
    }
    return typingSession.settings.suggestions || typingSession.settings.autoCorrect;
  }

  private contentTop(): number {
    if (emojiModel.searching) {
      return 72;
    }
    if (this.barOn()) {
      return 44;
    }
    return 0;
  }

  private returnText(): string {
    if (emojiModel.searching) {
      return 'Xong';
    }
    const key = typingSession.returnTitleKey;
    if (key === 'ret_go') { return 'Đi'; }
    if (key === 'ret_search') { return 'Tìm'; }
    if (key === 'ret_send') { return 'Gửi'; }
    if (key === 'ret_done') { return 'Xong'; }
    if (key === 'ret_next') { return 'Tiếp'; }
    return '';
  }

  private bump(): void {
    const tick = AppStorage.get<number>('kbTick') ?? 0;
    AppStorage.setOrCreate('kbTick', tick + 1);
  }

  private handleTouch(event: TouchEvent): void {
    if (typingSession.previewOn) {
      return;
    }
    const changed = event.changedTouches.length > 0 ? event.changedTouches : event.touches;
    if (changed.length === 0) {
      return;
    }
    if (this.emojiOn) {
      const point = changed[0];
      if (event.type === TouchType.Down) {
        this.downX = point.x;
        this.downY = point.y;
        this.emojiMoved = false;
      } else if (event.type === TouchType.Move) {
        const dx = point.x - this.downX;
        const dy = point.y - this.downY;
        if (dx * dx + dy * dy > 64) {
          this.emojiMoved = true;
        }
      } else if (event.type === TouchType.Up && !this.emojiMoved) {
        this.emojiTap(point.x, point.y);
      }
      return;
    }
    for (let i = 0; i < changed.length; i++) {
      const point = changed[i];
      if (event.type === TouchType.Down) {
        if (this.findTrack(point.id) !== null) {
          continue;
        }
        const track = new TouchTrack();
        track.id = point.id;
        track.downX = point.x;
        track.downY = point.y;
        track.x = point.x;
        track.y = point.y;
        this.tracks.push(track);
        this.down(track);
      } else if (event.type === TouchType.Move) {
        const track = this.findTrack(point.id);
        if (track !== null) {
          track.x = point.x;
          track.y = point.y;
          this.move(track);
        }
      } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
        const track = this.findTrack(point.id);
        if (track !== null) {
          track.x = point.x;
          track.y = point.y;
          this.up(track);
          this.dropTrack(point.id);
          this.restorePress();
        }
      }
    }
  }

  private findTrack(id: number): TouchTrack | null {
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].id === id) {
        return this.tracks[i];
      }
    }
    return null;
  }

  private dropTrack(id: number): void {
    const next: TouchTrack[] = [];
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].id !== id) {
        next.push(this.tracks[i]);
      }
    }
    this.tracks = next;
  }

  private down(track: TouchTrack): void {
    const x = track.x;
    const y = track.y;
    if (emojiModel.searching && y < 72) {
      if (y >= 28 && this.emojiResults.length > 0) {
        track.searchIndex = Math.max(0, Math.floor((x + this.resultScroll) / 44));
      }
      return;
    }
    if (this.barOn() && y < 44) {
      if (x < 65) {
        track.barIndex = -2;
      } else if (this.showHideKey() && x > this.boardWidth - 52) {
        track.barIndex = -4;
      } else if (typingSession.suggestions.length > 0) {
        const width = (this.boardWidth - 65 - this.hideSlot()) / typingSession.suggestions.length;
        track.barIndex = Math.min(typingSession.suggestions.length - 1, Math.max(0, Math.floor((x - 65) / width)));
      }
      return;
    }
    const localY = y - this.contentTop();
    const cell = this.hit(x, localY);
    if (cell === null) {
      return;
    }
    let chosen = cell;
    if (cell.kind === 'char' && typingSession.layer === 0 && cell.text >= 'a' && cell.text <= 'z') {
      const ctx = typingSession.wordContext();
      const picked = Driver.pickLetter(x, localY, ctx[0], ctx[1] === '1', this.letterKey, this.letterRects);
      if (picked.length === 1) {
        for (let i = 0; i < this.cells.length; i++) {
          if (this.cells[i].text === picked) {
            chosen = this.cells[i];
          }
        }
      }
    }
    track.active = chosen;
    this.active = chosen;
    this.pressed = chosen.id;
    this.popup = chosen.kind === 'char' ? chosen.label : '';
    this.popupX = chosen.x;
    if (chosen.kind === 'back') {
      if (emojiModel.searching) {
        emojiModel.deleteQuery();
        this.bump();
      } else {
        typingSession.onBackspace();
      }
      track.repeatCount = 0;
      track.hold = setTimeout(() => { this.startRepeat(track); }, 320);
    } else if (chosen.kind === 'shift') {
      typingSession.onShift();
    } else if (chosen.kind === 'layer') {
      const next = chosen.text === '2' ? 2 : chosen.text === '1' ? 1 : (typingSession.layer === 0 ? 1 : 0);
      typingSession.onLayer(next);
      track.slide = true;
    } else if (chosen.kind === 'globe') {
      track.hold = setTimeout(() => {
        keyboardController.showMenu();
        track.active = null;
        this.restorePress();
      }, 400);
    } else if (chosen.kind === 'space') {
      track.hold = setTimeout(() => {
        track.cursor = true;
        track.cursorAnchor = x;
      }, 350);
    } else if (chosen.kind === 'char') {
      track.hold = setTimeout(() => { this.showAlts(track, chosen); }, 380);
    }
  }

  private move(track: TouchTrack): void {
    const x = track.x;
    const y = track.y;
    if (track.cursor) {
      const step = 9 * this.boardWidth / 402;
      const n = Math.trunc((x - track.cursorAnchor) / step);
      if (n !== 0) {
        typingSession.onMoveCursor(n);
        track.cursorAnchor += n * step;
      }
      return;
    }
    if (track.showingAlts && this.alts.length > 0) {
      this.altIndex = Math.min(this.alts.length - 1, Math.max(0, Math.floor((x - this.altX) / 34)));
      return;
    }
    if (track.active === null) {
      return;
    }
    const dx = x - track.downX;
    const dy = y - track.downY;
    if (!track.slide && dx * dx + dy * dy < 324) {
      return;
    }
    const next = this.hit(x, y - this.contentTop());
    if (next !== null && next.id !== track.active.id && next.kind === 'char') {
      track.active = next;
      this.active = next;
      this.pressed = next.id;
      this.popup = next.label;
      this.popupX = next.x;
    }
  }

  private up(track: TouchTrack): void {
    const x = track.x;
    const y = track.y;
    this.clearHold(track);
    if (track.searchIndex >= 0) {
      const index = Math.floor((x + this.resultScroll) / 44);
      if (emojiModel.searching && y >= 28 && y < 72 && index === track.searchIndex &&
        index < this.emojiResults.length) {
        const item = this.emojiResults[index];
        emojiModel.record(item);
        typingSession.insertPlain(item);
      }
      return;
    }
    if (track.barIndex === -4) {
      if (y < 52 && x > this.boardWidth - 56) {
        keyboardController.hideKeyboard();
      }
      return;
    }
    if (track.barIndex === -2) {
      if (y < 52 && x < 65) {
        typingSession.onLanguage();
      }
      return;
    }
    if (track.barIndex >= 0) {
      const width = (this.boardWidth - 65 - this.hideSlot()) / Math.max(1, typingSession.suggestions.length);
      const index = Math.floor((x - 65) / width);
      if (y < 52 && index === track.barIndex) {
        typingSession.pickSuggestion(track.barIndex);
      }
      return;
    }
    if (track.cursor) {
      track.cursor = false;
      typingSession.onCursorEnd();
      return;
    }
    if (track.showingAlts && this.alts.length > 0) {
      const text = this.alts[this.altIndex];
      if (text !== undefined && text.length > 0) {
        typingSession.onAlternate(text);
      }
      this.alts = [];
      return;
    }
    const cell = track.active;
    if (cell === null) {
      return;
    }
    if (cell.kind === 'back' || cell.kind === 'shift' || cell.kind === 'layer') {
      return;
    }
    if (cell.kind === 'space') {
      if (emojiModel.searching) {
        emojiModel.typeQuery(' ');
        this.bump();
      } else {
        typingSession.onSpace();
      }
    } else if (cell.kind === 'return') {
      if (emojiModel.searching) {
        emojiModel.searching = false;
        this.bump();
      } else {
        typingSession.onReturn();
      }
    } else if (cell.kind === 'lang') {
      typingSession.onLanguage();
    } else if (cell.kind === 'emoji') {
      emojiModel.open = true;
      emojiModel.searching = false;
      emojiModel.refresh();
      this.bump();
    } else if (cell.kind === 'globe') {
      keyboardController.switchNext();
    } else if (cell.kind === 'char') {
      typingSession.rememberTouch(track.downX, track.downY - this.contentTop());
      if (emojiModel.searching) {
        emojiModel.typeQuery(cell.text.toLowerCase());
        this.bump();
      } else {
        typingSession.onChar(cell.text);
      }
      if (track.slide) {
        typingSession.onLayer(0);
        track.slide = false;
      }
    }
  }

  private showAlts(track: TouchTrack, cell: KeyCell): void {
    const upper = typingSession.shift !== 0;
    const list = alternatesFor(cell.text, upper);
    if (list.length === 0) {
      return;
    }
    track.showingAlts = true;
    this.alts = list;
    this.altIndex = 0;
    this.altX = Math.max(4, Math.min(this.boardWidth - list.length * 34 - 8, cell.x));
    this.altY = Math.max(0, cell.y - 52);
    this.popup = '';
  }

  private startRepeat(track: TouchTrack): void {
    track.repeat = setInterval(() => {
      track.repeatCount++;
      if (emojiModel.searching) {
        emojiModel.deleteQuery();
        this.bump();
      } else {
        typingSession.onBackspaceRepeat(track.repeatCount);
      }
    }, 48);
  }

  private clearHold(track: TouchTrack): void {
    if (track.hold >= 0) {
      clearTimeout(track.hold);
      track.hold = -1;
    }
    if (track.repeat >= 0) {
      clearInterval(track.repeat);
      track.repeat = -1;
    }
  }

  private restorePress(): void {
    if (this.tracks.length === 0) {
      this.resetTouch();
      return;
    }
    const track = this.tracks[this.tracks.length - 1];
    const cell = track.active;
    if (cell === null || track.showingAlts) {
      this.pressed = '';
      this.popup = '';
      return;
    }
    this.active = cell;
    this.pressed = cell.id;
    this.popup = cell.kind === 'char' ? cell.label : '';
    this.popupX = cell.x;
  }

  private resetTouch(): void {
    this.active = null;
    this.pressed = '';
    this.popup = '';
  }

  private hit(x: number, y: number): KeyCell | null {
    let best: KeyCell | null = null;
    let bestDist = 1e12;
    for (let i = 0; i < this.cells.length; i++) {
      const cell = this.cells[i];
      const padX = 5;
      const padY = 8;
      if (x < cell.x - padX || x > cell.x + cell.w + padX || y < cell.y - padY || y > cell.y + cell.h + padY) {
        continue;
      }
      const dx = x - (cell.x + cell.w / 2);
      const dy = y - (cell.y + cell.h / 2);
      const dist = dx * dx + dy * dy;
      if (dist < bestDist) {
        bestDist = dist;
        best = cell;
      }
    }
    if (best !== null) {
      return best;
    }
    let near: KeyCell | null = null;
    let nearDist = 26 * 26;
    for (let i = 0; i < this.cells.length; i++) {
      const cell = this.cells[i];
      let dx = 0;
      if (x < cell.x) {
        dx = cell.x - x;
      } else if (x > cell.x + cell.w) {
        dx = x - (cell.x + cell.w);
      }
      let dy = 0;
      if (y < cell.y) {
        dy = cell.y - y;
      } else if (y > cell.y + cell.h) {
        dy = y - (cell.y + cell.h);
      }
      const dist = dx * dx + dy * dy;
      if (dist < nearDist) {
        nearDist = dist;
        near = cell;
      }
    }
    return near;
  }
}

