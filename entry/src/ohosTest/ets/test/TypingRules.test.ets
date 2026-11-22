import { describe, it, expect } from '@ohos/hypium';
import { Contractions } from '../../../main/ets/ime/Contractions';
import { ReturnKey } from '../../../main/ets/ime/ReturnKey';

export default function typingRulesTest() {
  describe('typingRules', () => {
    it('contractionDont', 0, () => {
      expect(Contractions.fix('dont')).assertEqual("don't");
      expect(Contractions.fix('Dont')).assertEqual("Don't");
      expect(Contractions.fix('wont')).assertEqual("won't");
      expect(Contractions.fix('were')).assertEqual('');
      expect(Contractions.fix('ill')).assertEqual('');
      expect(Contractions.fix('Ill')).assertEqual("I'll");
    });

    it('returnKey', 0, () => {
      expect(ReturnKey.labelKey(3, false)).assertEqual('ret_search');
      expect(ReturnKey.isAction(2, false)).assertEqual(true);
      expect(ReturnKey.labelKey(0, false)).assertEqual('');
      expect(ReturnKey.labelKey(3, true)).assertEqual('');
      expect(ReturnKey.isBlue(6, false)).assertEqual(true);
    expect(ReturnKey.isBlue(5, false)).assertEqual(false);
    });
  });
}
