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

import fs from '@ohos.file.fs';
import LogUtil from '../utils/LogUtil';
import LogMethod from '../common/LogDecorator';
import picker from '@ohos.file.picker';

import { AbilityManager } from '../common/AbilityManager';
import { BaseAdapter } from '../common/BaseAdapter';
import { BusinessError } from '@ohos.base';
import { image } from '@kit.ImageKit';
import { inject, injectable } from 'inversify';
import { ContextAdapter } from './ContextAdapter';

const TAG: string = 'Dialog';

interface IMessageBoxSettings {
  parent_id: number,
  type: string,
  title: string,
  message: string,
  detail: string,
  checkbox_label: string,
  checkbox_checked: boolean,
  cancel_id: number,
  default_id: number,
  buttons: string[]
}

interface IFilter {
  name: string,
  extensions: string[]
}

interface IOpenDialogSettings {
  parent_id: number,
  title: string,
  message: string,
  button_label: string,
  default_path: string,
  filters: IFilter[],
  properties_open_directory: boolean,
  properties_open_mixed: boolean,
  properties_multi_selections: boolean
}

export interface IMessageBoxParams {
  messageBoxSettings: IMessageBoxSettings | undefined,
  icon: image.PixelMap | undefined,
  callback: (buttonId: number, checkboxChecked: boolean) => void
}

export interface MessageBoxData {
  id: string,
  dialogController: CustomDialogController,
  setMessageBoxParams: (messageBoxParams: IMessageBoxParams) => void;
}

@injectable()
export class DialogAdapter extends BaseAdapter {
  private abilityManager: AbilityManager = new AbilityManager();
  private static PATH_PREFIX: string = 'file://docs'; 
  private static DEFAULT_DIR: string = 'file://docs/storage/Users/currentUser';
  private static MAX_SELECT_NUMBER: number = 500;
  private ctxAdapter: ContextAdapter;
  private allFIleDescriptionId: number = $r("app.string.upload_all_file_description").id;

  constructor(@inject(ContextAdapter) ctxAdapter: ContextAdapter) {
    super();
    this.ctxAdapter = ctxAdapter;
  }

  @LogMethod
  showMessageBox(settings: string, buffer: ArrayBuffer, width: number, height: number,  callback: (button_id: number, checkbox_checked: boolean) => void) {
    LogUtil.info(TAG, 'messagebox settings ' + settings);
    let icon: image.PixelMap | undefined = this.convertImagePixelMap(width, height, buffer);
    let boxSettings: IMessageBoxSettings = JSON.parse(settings);
    let params: IMessageBoxParams = {
      messageBoxSettings: boxSettings,
      icon: icon,
      callback: callback
    };
    LogUtil.error(TAG, 'parentId ' + boxSettings.parent_id);
    let parentId = boxSettings.parent_id === -1 ? 1 : boxSettings.parent_id;
    let messageBoxManager: MessageBoxData | undefined = this.abilityManager.getMessageBox(parentId);
    messageBoxManager?.setMessageBoxParams(params);
    messageBoxManager?.dialogController.open();
  }

  @LogMethod
  showErrorBox(title: string, content: string, callback: (result: boolean) => void) {
    let isClicked = false;
    AlertDialog.show({
      title: title,
      message: content,
      autoCancel: false,
      cancel: () => {},
      primaryButton: {
        value: $r('app.string.button_ok'),
        style: DialogButtonStyle.HIGHLIGHT,
        action: () => {
          if (isClicked) {
            return;
          }
          isClicked = true;
          callback(true);
        },
      }
    });
  }

  @LogMethod
  showOpenDialog(settings: string, callback: (filePaths: string[], canceled: boolean) => void) {
    LogUtil.info(TAG, 'ShowOpenDialog ' + settings);
    let DocumentSelectOptions = new picker.DocumentSelectOptions();
    let dialogSettings: IOpenDialogSettings = JSON.parse(settings);
    if (dialogSettings.properties_open_directory) {
      DocumentSelectOptions.selectMode = picker.DocumentSelectMode.FOLDER;
      if (dialogSettings.properties_open_mixed)
        DocumentSelectOptions.selectMode = picker.DocumentSelectMode.MIXED;
    }
    if (dialogSettings.properties_multi_selections) {
      DocumentSelectOptions.maxSelectNumber = DialogAdapter.MAX_SELECT_NUMBER;
    }
    const context = this.ctxAdapter.getContext();
    let allFileDescription = context.resourceManager.getStringSync(this.allFIleDescriptionId);
    if (dialogSettings.filters.length > 0) {
      DocumentSelectOptions.fileSuffixFilters = this.getFilterArray(dialogSettings.filters);
    } else {
      DocumentSelectOptions.fileSuffixFilters = [allFileDescription + "|.*"];
    }
    let dirAndFile: string[] = this.handleDefaultPath(dialogSettings.default_path);
    LogUtil.info(TAG, 'showOpenDialog dirAndFile: ' + `${dirAndFile[0]}-${dirAndFile[1]}`);
    DocumentSelectOptions.defaultFilePathUri = dirAndFile[0];
    let documentPicker = new picker.DocumentViewPicker();
    documentPicker.select(DocumentSelectOptions).then((DocumentSelectResult: Array<string>) => {
      LogUtil.info(TAG, 'DocumentViewPicker.select successfully, DocumentSelectResult uri: ' + JSON.stringify(DocumentSelectResult));
      if (DocumentSelectResult.length === 0) {
        callback([], true);
      } else {
        callback(DocumentSelectResult, false);
      }
    }).catch((err: BusinessError) => {
      LogUtil.error(TAG, 'DocumentViewPicker.select failed with err: ' + JSON.stringify(err));
      callback([], true);
    });
  }

  @LogMethod
  showSaveDialog(settings: string, callback: (filePath: string, canceled: boolean) => void) {
    LogUtil.info(TAG, 'ShowSaveDialog ' + settings);
    let dialogSettings: IOpenDialogSettings = JSON.parse(settings);
    let DocumentSaveOptions = new picker.DocumentSaveOptions();
    let dirAndFile: string[] = this.handleDefaultPath(dialogSettings.default_path);
    LogUtil.info(TAG, 'ShowSaveDialog dirAndFile: ' + `${dirAndFile[0]}-${dirAndFile[1]}`);
    DocumentSaveOptions.defaultFilePathUri = dirAndFile[0];
    DocumentSaveOptions.newFileNames = [`${dirAndFile[1]}`];
    const context = this.ctxAdapter.getContext();
    let allFileDescription = context.resourceManager.getStringSync(this.allFIleDescriptionId);
    if (dialogSettings.filters.length > 0) {
      DocumentSaveOptions.fileSuffixChoices = this.getFilterArray(dialogSettings.filters);
    } else {
      DocumentSaveOptions.fileSuffixChoices = [allFileDescription + "|.*"];
    }
    let documentPicker = new picker.DocumentViewPicker();
    documentPicker.save(DocumentSaveOptions).then((DocumentSaveResult: Array<string>) => {
      LogUtil.info(TAG, 'DocumentViewPicker.save successfully, DocumentSaveResult uri: ' + JSON.stringify(DocumentSaveResult));
      if (DocumentSaveResult.length === 0) {
        callback('', true);
      } else {
        callback(DocumentSaveResult[0], false);
      }
    }).catch((err: BusinessError) => {
      LogUtil.error(TAG, 'DocumentViewPicker.save failed with err: ' + JSON.stringify(err));
      callback('', true);
    });
  }

  private handleDefaultPath(default_path: string) {
    let dirAndFile: string[] = [DialogAdapter.DEFAULT_DIR, ''];
    try {
      let path: string = default_path.trim();
      let exist = fs.accessSync(path);
      if (!exist) {
        let fileNameIndex: number = path.lastIndexOf('/');
        let dirPath: string = path.slice(0, fileNameIndex);
        let fileName: string = path.slice(fileNameIndex + 1);
        if (fs.accessSync(dirPath)) {
          dirAndFile[0] = DialogAdapter.PATH_PREFIX + dirPath;
        }
        dirAndFile[1] = fileName;
      } else {
        let stat = fs.statSync(path);
        if (stat.isDirectory()) {
          dirAndFile[0] = DialogAdapter.PATH_PREFIX + path;
        } else if (stat.isFile()) {
          let fileNameIndex: number = path.lastIndexOf('/');
          let dirPath: string = path.slice(0, fileNameIndex);
          let fileName: string = path.slice(fileNameIndex + 1);
          dirAndFile[0] = DialogAdapter.PATH_PREFIX + dirPath;
          dirAndFile[1] = fileName;
        }
      }
    } catch (err) {
      LogUtil.error(TAG, 'handleDefaultPath failed with err: ' + JSON.stringify(err));
    }
    return dirAndFile;
  }

  private getFilterArray(filters: IFilter[]): Array<string> {
    let copy = new Array<string>();
    for (const filter of filters) {
      copy.push(filter.name + "(*." + filter.extensions.join(";*.") + ")|." + filter.extensions.join(",."));
    }
    return copy;
  }

  private convertImagePixelMap(width: number, height: number, buff: ArrayBuffer): image.PixelMap | undefined {
    let pixmap: image.PixelMap;
    if (width === 0 || height === 0) {
      LogUtil.warn(TAG, 'image is empty, no conversion required');
      return undefined;
    }
    let opts: image.InitializationOptions = {
      size: {
        height: height,
        width: width
      }
    }
    try {
      pixmap = image.createPixelMapSync(buff, opts);
      return pixmap;
    } catch (error) {
      LogUtil.error(TAG, 'failed convert image pixel map because: ' +  JSON.stringify(error));
      return undefined;
    }
  }
}
