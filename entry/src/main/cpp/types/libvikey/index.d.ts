export interface VikeyNative {
  create(): number;
  destroy(handle: number): void;
  language(handle: number): number;
  setLanguage(handle: number, language: number): void;
  configure(handle: number, autoSwitch: boolean, pause: number, spelling: boolean, restore: boolean,
    modern: boolean): void;
  setTelexStyle(style: number): void;
  typeChar(handle: number, text: string, now: number): string;
  backspace(handle: number, now: number): string;
  manualSwitch(handle: number, now: number): void;
  resetContext(handle: number): void;
  pickLetter(x: number, y: number, prefix: string, vietnamese: number, letters: string, rects: number[]): number;
  candidates(typed: string, xs: number[], ys: number[], vietnamese: number, letters: string, rects: number[],
    max: number): string[];
  shouldCorrect(typed: string, packed: string[]): boolean;
  completions(prefix: string, vietnamese: number, max: number): string[];
  wordScore(vietnamese: number, letters: string): number;
  accentForms(typed: string, max: number): string[];
}

declare const vikey: VikeyNative;
export default vikey;
