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

import bundleManager from '@ohos.bundle.bundleManager';
import { BusinessError } from '@ohos.base';
import { Size, window } from '@kit.ArkUI';

import { AbilityManager } from '../common/AbilityManager';
import { BaseWindowAdapter } from '../common/BaseWindowAdapter';
import { ContextAdapter } from './ContextAdapter';
import { inject, injectable } from 'inversify';
import LogMethod from '../common/LogDecorator';
import LogUtil from '../utils/LogUtil';
import { NewWindowParam, WindowType, WindowBound } from "../interface/CommonInterface"
import { WindowStyle, IStyleData, IUpdateStyle } from '../common/WindowStyle';

const TAG: string = 'PopupWindow';

@injectable()
export class PopupWindowAdapter extends BaseWindowAdapter {
  private abilityManager: AbilityManager;
  private bundleName: string = 'com.huawei.ohos_electron';
  private bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION |
                        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_METADATA;

  constructor(
    @inject(AbilityManager) abilityManager: AbilityManager,
    @inject(ContextAdapter) ctxAdapter: ContextAdapter
  ) {
    super(ctxAdapter);
    this.abilityManager = abilityManager;

    try {
      let data = bundleManager.getBundleInfoForSelfSync(this.bundleFlags);
      this.bundleName = data.name;
    } catch (err) {
      let message = (err as BusinessError).message;
      LogUtil.error(TAG, `getBundleInfoForSelfSync failed.: ${message}`);
    }
  }

  @LogMethod
  createWindow(param: NewWindowParam) {
    let proxy = this.abilityManager.getProxy(param.parent_id);
    proxy?.createSubWindow(param.window_id)
      .then((data: window.Window) => {
        this.adjustWindow(data, param, WindowType.SUB_WINDOW);
      }).catch((err: BusinessError) => {
      LogUtil.error(TAG, 'Failed to create the subWindow. Cause: ' + JSON.stringify(err));
    });
  }

  @LogMethod
  private adjustWindow(windowClass: window.Window, param: NewWindowParam, windowType: WindowType) {
    super.initialize(param.window_id, windowClass);
    this.abilityManager?.addProxy(this);
    windowClass.setSubWindowModal(param.is_modal);
    windowClass.moveWindowTo(param.bounds.left, param.bounds.top, (err: BusinessError) => {
      let errCode: number = err.code;
      if (errCode) {
        LogUtil.error(TAG, `${windowType} failed to move the window. Cause:${JSON.stringify(err)}`);
        return;
      }
      LogUtil.info(TAG, `${windowType} succeeded in moving the window.`);
    });
    windowClass.resize(param.bounds.width, param.bounds.height, (err: BusinessError) => {
      let errCode: number = err.code;
      if (errCode) {
        LogUtil.error(TAG, `${windowType} failed to change the window size. Cause:${JSON.stringify(err)}`);
        return;
      }
      LogUtil.info(TAG, `${windowType} succeeded in changing the window size.`);
    });

    const para: Record<string, string | IUpdateStyle> = {
      'xcomponentId': param.window_id,
      'updateStyle': {
        'registerUpdateStyleFunction': WindowStyle.registerUpdateStyleFunction,
        'removeUpdateStyleFunction': WindowStyle.removeUpdateStyleFunction
      }
    };
    let storage: LocalStorage = new LocalStorage(para);
    windowClass.loadContent("pages/Index", storage, (err: BusinessError) => {
      let errCode: number = err.code;
      if (errCode) {
        LogUtil.error(TAG, `${windowType} failed to load the content. Cause:${JSON.stringify(err)}`);
        return;
      }
      LogUtil.info(TAG, `${windowType} succeeded in loading the content.`);
      (windowClass as window.Window).showWindow((err: BusinessError) => {
        let errCode: number = err.code;
        if (errCode) {
          LogUtil.error(TAG, `${windowType} failed to show the window. Cause:${JSON.stringify(err)}`);
          return;
        }
        LogUtil.info(TAG, `${windowType} succeeded in showing the window.`);
      });
    });
  }

  @LogMethod
  closeWindow(id: number) {
    let windowClass = this.abilityManager.getProxy(id)?.getWindow();
    windowClass?.destroyWindow((err: BusinessError) => {
      let errCode: number = err.code;
      if (errCode) {
        LogUtil.error(TAG, 'Failed to destroy the window. Cause: ' + JSON.stringify(err));
        return;
      }
      LogUtil.info(TAG, 'Succeeded in destroying the window.');
    });
  }

  @LogMethod
  showWindow(id: number) {
    let windowClass = this.abilityManager.getProxy(id)?.getWindow();
    let promise = windowClass?.showWindow();
    promise?.then(() => {
        LogUtil.info(TAG, 'Succeeded in showing the window.');
    }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `Failed to show the window. Cause code: ${err.code}, message: ${err.message}`);
    });
  }

  @LogMethod
  hideWindow(id: number) {
    let windowClass = this.abilityManager.getProxy(id)?.getWindow();
    let promise = windowClass?.minimize();
    promise?.then(() => {
        LogUtil.info(TAG, 'Succeeded in hiding the window.');
    }).catch((err: BusinessError) => {
        LogUtil.error(TAG, `Failed to hide the window. Cause code: ${err.code}, message: ${err.message}`);
    });
  }

  @LogMethod
  activateWindow(id: number) {
    this.showWindow(id);
  }

  @LogMethod
  setBounds(id: number,
            bounds: WindowBound) {
    let windowClass = this.abilityManager.getProxy(id)?.getWindow();
    if (!windowClass) {
      LogUtil.error(TAG, 'Failed to obtain the popup window.');
      return;
    }

    try {
      windowClass.moveWindowToAsync(bounds.left, bounds.top)
        .catch((err: BusinessError) => {
        LogUtil.error(TAG, 'Failed to move the window. Cause:' + JSON.stringify(err));
        });
      windowClass?.resizeAsync(bounds.width, bounds.height)
        .catch((err: BusinessError) => {
          LogUtil.error(TAG, 'Failed to change the window size. Cause:' + JSON.stringify(err));
        });
    } catch (exception) {
      LogUtil.error(TAG, 'move the window exception. Cause:' + JSON.stringify(exception));
    }
  }

  @LogMethod
  setWindowLimits(minWidth: number,
                  minHeight: number,
                  maxWidth: number,
                  maxHeight: number,
                  id: number) {
    let windowClass = this.abilityManager.getProxy(id)?.getWindow();
    const mainWindowProp = windowClass?.getWindowProperties();
    let xComBorder: number = mainWindowProp?.drawableRect.left || 0;
    let xComTop: number = mainWindowProp?.drawableRect.top || 0;

    try {
      let windowLimits: window.WindowLimits = {
        minWidth: minWidth === 0 ? minWidth : minWidth + xComBorder + xComBorder,
        minHeight: minHeight === 0 ? minHeight : minHeight + xComTop + xComBorder,
        maxWidth: maxWidth === 0 ? maxWidth : maxWidth + xComBorder + xComBorder,
        maxHeight: maxHeight === 0 ? maxHeight : maxHeight + xComTop + xComBorder,
      };

      windowClass?.setWindowLimits(windowLimits)
        .catch((err: BusinessError) => {
          LogUtil.error(TAG, 'Failed to change the window limits. Cause: ' + JSON.stringify(err));
        });
    } catch (exception) {
      LogUtil.error(TAG, 'change the window limits exception. Cause:' + JSON.stringify(exception));
    }
  }
};
