import React from 'react';
import OverlayModal from '../global/shared/overlay_modal';
import {CCEmail, DemoEmail, GmailAuthPath, StorageRestoreStateKey, FounderDisableScannerPath} from '../global/constants.js.erb';
import {SessionStorage} from '../global/storage.js.erb';
import Breadcrumb from '../global/breadcrumbs';
import Store from '../global/store';
import Actions from '../global/actions';
import {currentPage, ffetch} from '../global/utils';
import {Button, Colors} from 'react-foundation';

export default class EmailIntegrationModal extends React.Component {
  state = {
    founder: Store.get('founder', {}),
  };

  componentWillMount() {
    this.subscription = Store.subscribe('founder', founder => this.setState({founder}));
  }

  componentWillUnmount() {
    Store.unsubscribe(this.subscription);
  }

  authWithGoogle = () => {
    SessionStorage.set(StorageRestoreStateKey, {
      breadcrumb: Breadcrumb.peek(),
      location: currentPage(),
    });
    window.location.href = GmailAuthPath;
  };

  disableScanner = () => {
    ffetch(FounderDisableScannerPath, 'POST').then(founder => Actions.trigger('refreshFounder', founder));
  };

  renderTop() {
    return <h3>Email Integration</h3>;
  }

  renderScannerButton() {
    if (this.state.founder['scanner_enabled?']) {
      return (
        <Button color={Colors.ALERT} onClick={this.disableScanner}>
          Disable Inbox Scanner
        </Button>
      );
    }
    return (
      <Button color={Colors.SUCCESS} onClick={this.authWithGoogle}>
        Enable Inbox Scanner With Google
      </Button>
    );
  }

  renderBottom() {
    return (
      <div className="info">
        <p>
          VCWiz can automatically track your email conversations with investors!
          Allowing VCWiz to integrate with your email will give you access to detailed email analytics, without having to manually update your tracker.
        </p>
        <h4>VCWiz CC Address</h4>
        <p>
          You can start by simply CCing <b>{CCEmail}</b> on any email you send to investors.
          Give it a try with <a target="_blank" href={`mailto:${DemoEmail}?subject=VCWiz Test&cc=${CCEmail}`}>{DemoEmail}</a> now!
        </p>
        <h4>VCWiz Inbox Scanner</h4>
        <p>
          If you don't want the annoyance of adding VCWiz to every email, you can give us permission to scan your Gmail inbox.
          We will automatically detect emails back and forth with investors, and add them to your tracker.
          Don't worry, VCWiz will never read any of your emails! It only looks at senders and recipients.
        </p>
        {this.renderScannerButton()}
      </div>
    );
  }

  render() {
    return (
      <OverlayModal
        name="email_integration"
        top={this.renderTop()}
        bottom={this.renderBottom()}
        {...this.props}
      />
    );
  }
}