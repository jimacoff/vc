import React from 'react';
import Header from './global/shared/header';
import classNames from 'classnames';
import {currentPage} from './global/utils';
import Store from './global/store';
import Storage from './global/storage.js.erb';
import {StorageRestoreStateKey} from './global/constants.js.erb';
import { canUseDOM } from 'exenv';

export default class VCWiz extends React.Component {
  static defaultProps = {
    header: null,
    modal: null,
    showIntro: false,
  };

  componentWillMount() {
    if (!canUseDOM) {
      return;
    }
    const restoreState = Storage.get(StorageRestoreStateKey);
    if (restoreState) {
      if (currentPage() !== restoreState.location) {
        window.location = restoreState.location;
      } else {
        Storage.remove(StorageRestoreStateKey);
        Store.set(StorageRestoreStateKey, restoreState);
      }
    }
  }

  renderHeader() {
    const { page, header } = this.props;
    if (!header) {
      return null;
    }
    return (
      <div className={classNames('vcwiz-header', `${page}-page-header`)}>
        {header}
      </div>
    );
  }

  renderBody() {
    const { page, body } = this.props;
    return (
      <div className={classNames('vcwiz-body', `${page}-page-body`)}>
        {body}
      </div>
    );
  }

  render() {
    const { page, showIntro } = this.props;
    return (
      <div id="vcwiz" className={classNames('full-screen', 'vcwiz', `toplevel-${page}-page`)}>
        <Header showIntro={showIntro} />
        <div className={classNames('vcwiz-page', `${page}-page`, {'full-screen': !showIntro})}>
          {this.renderHeader()}
          {this.renderBody()}
        </div>
        {this.props.modal}
      </div>
    );
  }
}