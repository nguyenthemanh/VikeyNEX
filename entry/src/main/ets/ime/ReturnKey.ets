import { inputMethod } from '@kit.IMEKit';

/** Return-key title resource, matching the Android IME actions Vikey shows. */
export class ReturnKey {
  static labelKey(enter: number, multiline: boolean): string {
    if (multiline || enter === inputMethod.EnterKeyType.NEWLINE || enter === inputMethod.EnterKeyType.UNSPECIFIED ||
      enter === inputMethod.EnterKeyType.NONE) {
      return '';
    }
    if (enter === inputMethod.EnterKeyType.GO) { return 'ret_go'; }
    if (enter === inputMethod.EnterKeyType.SEARCH) { return 'ret_search'; }
    if (enter === inputMethod.EnterKeyType.SEND) { return 'ret_send'; }
    if (enter === inputMethod.EnterKeyType.DONE) { return 'ret_done'; }
    if (enter === inputMethod.EnterKeyType.NEXT || enter === inputMethod.EnterKeyType.PREVIOUS) { return 'ret_next'; }
    return '';
  }

  static isAction(enter: number, multiline: boolean): boolean {
    return ReturnKey.labelKey(enter, multiline).length > 0;
  }

  static isBlue(enter: number, multiline: boolean): boolean {
    const key = ReturnKey.labelKey(enter, multiline);
    return key.length > 0 && key !== 'ret_next';
  }
}
