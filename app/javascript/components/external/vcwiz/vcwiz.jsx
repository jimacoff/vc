import React from 'react';
import Header from './global/shared/header';
import classNames from 'classnames';
import {currentPage, ffetch} from './global/utils';
import Store from './global/store';
import Actions from './global/actions';
import {SessionStorage} from './global/storage.js.erb';
import {StorageRestoreStateKey, FounderPath} from './global/constants.js.erb';
import { canUseDOM } from 'exenv';

export default class VCWiz extends React.Component {
  static defaultProps = {
    header: null,
    modal: null,
    showIntro: false,
    subtitle: 'Raise Your Seed Round',
  };

  onClick = e => {
    Store.set('lastClick', e);
  };

  componentWillMount() {
    Store.set('founder', window.gon.founder);
    Actions.register('refreshFounder', this.refreshFounder);

    if (!canUseDOM) {
      return;
    }

    document.onreadystatechange = () => {
      if (document.readyState === 'complete') {
        Store.set('isReady', true);
      }
    };
    if (document.readyState === 'complete') {
      Store.set('isReady', true);
    }

    const restoreState = SessionStorage.get(StorageRestoreStateKey);
    if (restoreState) {
      if (currentPage() !== restoreState.location) {
        window.location = restoreState.location;
      } else {
        SessionStorage.remove(StorageRestoreStateKey);
        Store.set(StorageRestoreStateKey, restoreState);
      }
    }
  }

  componentWillUnmount() {
    Actions.unregister('refreshFounder');
  }

  refreshFounder = founder => {
    if (founder) {
      Store.set('founder', founder);
    } else {
      ffetch(FounderPath).then(founder => Store.set('founder', founder));
    }
  };

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

  renderFooter() {
    const { page, footer } = this.props;
    if (!footer) {
      return null;
    }
    return (
      <div className={classNames('vcwiz-footer', `${page}-page-footer`)}>
        {footer}
      </div>
    );
  }

  render() {
    const { page, showIntro, showLogin, subtitle } = this.props;
    return (
      <div id="vcwiz" className={classNames('full-screen', 'vcwiz', `toplevel-${page}-page`)} onClick={this.onClick}>
        <Header subtitle={subtitle} showIntro={showIntro} showLogin={showLogin} />
        <div className={classNames('vcwiz-page', `${page}-page`, {'full-screen': !showIntro})}>
          {this.renderHeader()}
          {this.renderBody()}
          {this.renderFooter()}
        </div>
        {this.props.modal}
      </div>
    );
  }
}