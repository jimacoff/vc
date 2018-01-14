import React from 'react';
import Modal from 'react-modal';
import classNames from 'classnames';
import Breadcrumb from '../breadcrumbs';
import {doNotPropagate, saveCurrentRestoreState} from '../utils';

export default class OverlayModal extends React.Component {
  static defaultProps = {
    showClose: true,
    isOpen: true,
    idParams: {},
  };

  componentDidMount() {
    Breadcrumb.push(this.props.name, 'modal', this.props.idParams);
    window.onbeforeunload = () => saveCurrentRestoreState();
  }

  componentWillUnmount() {
    this.afterClose();
    Breadcrumb.pop();
    window.onbeforeunload = undefined;
  }

  componentWillReceiveProps(nextProps) {
    if (!_.isEqual(nextProps.idParams, this.props.idParams)) {
      Breadcrumb.replace(nextProps.idParams);
    }
  }

  renderModal() {
    const { top, bottom, name } = this.props;
    let wrappedTop = top && (
      <div className={classNames('overlay-modal-top', `${name}-modal-top`)}>
        {top}
      </div>
    );
    let wrappedBottom = bottom && (
      <div className={classNames('overlay-modal-bottom', `${name}-modal-bottom`)}>
        {bottom}
      </div>
    );
    return (
      <div className={classNames('overlay-modal', `${name}-modal`)}>
        {wrappedTop || null}
        {wrappedBottom || null}
      </div>
    )
  }

  onCloseClick = e => {
    doNotPropagate(e);
    this.onClose();
  };

  renderCloseButton() {
    if (!this.props.showClose) {
      return null;
    }
    return <div className="close-icon" onClick={this.onCloseClick}>x</div>;
  }

  stopWheel = event => event.stopPropagation();
  afterOpen = () => this.modal && this.modal.node.addEventListener('wheel', this.stopWheel);
  afterClose = () => this.modal && this.modal.node.removeEventListener('wheel', this.stopWheel);

  onClose = (...args) => {
    this.props.onClose(...args);
    this.afterClose();
  };

  render() {
    const { name, modal, isOpen, className } = this.props;
    if (!isOpen) {
      return null;
    }
    return (
      <Modal
        isOpen={isOpen}
        onRequestClose={this.onClose}
        contentLabel={name}
        overlayClassName={classNames('modal-overlay', `${name}-modal-overlay`)}
        className={classNames('modal-content', `${name}-modal-content`, className)}
        onAfterOpen={this.afterOpen}
        ref={modal => { this.modal = modal }}
      >
        {this.renderCloseButton()}
        <div className={classNames('overlay-modal-wrapper', `${name}-modal-wrapper`)}>
          {modal ? modal : this.renderModal()}
        </div>
      </Modal>
    )
  }
}