import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'WatermarkApp', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'WatermarkApp', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'WatermarkApp', '%{public}s', 'Ability onWindowStageCreate');

    const mainWindow = windowStage.getMainWindowSync();
    mainWindow.setWindowSystemBarProperties({
      statusBarColor: '#D8ECF8',
      statusBarContentColor: '#1E2A3B',
      navigationBarColor: '#F2F0E9',
      navigationBarContentColor: '#1E2A3B'
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'WatermarkApp', 'Failed to load the content. Cause: %{public}s',
          JSON.stringify(err) ?? '');
        return;
      }
      hilog.info(0x0000, 'WatermarkApp', 'Succeeded in loading the content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'WatermarkApp', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'WatermarkApp', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'WatermarkApp', '%{public}s', 'Ability onBackground');
  }
}
