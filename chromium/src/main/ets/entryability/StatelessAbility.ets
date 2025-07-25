/*
 * Copyright (c) 2023-2025 Haitai FangYuan Co., Ltd.
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of
 *    conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list
 *    of conditions and the following disclaimer in the documentation and/or other materials
 *    provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used
 *    to endorse or promote products derived from this software without specific prior written
 *    permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 * ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
 
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { Configuration } from '@ohos.app.ability.Configuration';
import window from '@ohos.window';
import Want from '@ohos.app.ability.Want';

import { deviceInfo } from '@kit.BasicServicesKit';

import { WebAbility } from 'web_engine';;
 
export default class StatelessAbility extends WebAbility {
  onConfigurationUpdate(config: Configuration) {
    super.onConfigurationUpdate(config);
  }
 
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam) {
    super.onCreate(want, launchParam);
  }
 
  async onPrepareToTerminateAsync(): Promise<boolean> {
    return await super.onPrepareToTerminateAsync();
  }

  async onDestroy(): Promise<void> {
    await super.onDestroy();
  }
 
  onWindowStageCreate(windowStage: window.WindowStage) {
    super.onWindowStageCreate(windowStage);
    if (deviceInfo.sdkApiVersion >= 14) {
      windowStage.setWindowRectAutoSave(false);
    }
  }
 
  onWindowStageDestroy() {
    super.onWindowStageDestroy();
  }
 
  onForeground() {
    super.onForeground();
  }
 
  onBackground() {
    super.onBackground();
  }
 
  override getContentPath(): string {
    return 'pages/Index';
  }
};
