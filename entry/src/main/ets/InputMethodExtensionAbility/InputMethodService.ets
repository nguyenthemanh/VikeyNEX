import { InputMethodExtensionAbility } from '@kit.IMEKit';
import { Configuration, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { keyboardController } from './model/KeyboardController';

const TAG = 'VikeyIME';

export default class InputMethodService extends InputMethodExtensionAbility {
  onCreate(want: Want): void {
    hilog.info(0x0000, TAG, 'onCreate %{public}s', want.abilityName ?? '');
    keyboardController.onCreate(this.context);
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'onDestroy');
    keyboardController.onDestroy();
  }

  onConfigurationUpdate(_newConfig: Configuration): void {
    keyboardController.syncChrome();
  }
}
