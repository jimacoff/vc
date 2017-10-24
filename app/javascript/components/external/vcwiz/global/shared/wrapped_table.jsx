import React from 'react';
import {timestamp, withDims} from '../utils';
import LazyArray from '../lazy_array';

export default class WrappedTable extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      currentModal: null,
      ...this.state = this.nextState(props),
    };
  }

  nextState(props) {
    return {
      array: new LazyArray(props.source, props.items, this.onArrayUpdate),
      lastUpdate: timestamp(),
    };
  }

  componentWillReceiveProps(nextProps) {
    if (nextProps.resultsId !== this.props.resultsId) {
      this.setState(this.nextState(nextProps));
    }
  }

  onArrayUpdate = () => {
    this.setState({lastUpdate: timestamp()});
  };

  onModalClose = () => {
    this.setState({currentModal: null});
  };

  onCellClick = (i, key) => {
    this.setState({currentModal: [i, key]});
  };

  getModal(key) {
    const { modal } = this.props;
    if (!modal) {
      return null;
    }
    if (_.isObject(modal) && !_.isFunction(modal)) {
      return modal[key];
    } else if (modal.prototype.isReactComponent) {
      return modal;
    } else if (_.isFunction(modal)) {
      return modal(key);
    } else {
      return null;
    }
  }

  renderCurrentModal() {
    const { currentModal, array } = this.state;
    if (currentModal === null) {
      return null;
    }
    const [i, key] = currentModal;
    const Modal = this.getModal(key);
    if (!Modal) {
      return null;
    }
    return (
      <Modal
        onClose={this.onModalClose}
        {...array.getSync(i)}
      />
    );
  }

  render() {
    const { array } = this.state;
    const { table, modal, ...props } = this.props;
    const BackingTable = withDims(table);
    return (
      <div className="full-screen">
        {this.renderCurrentModal()}
        <BackingTable onCellClick={this.onCellClick} array={array} {...props} />
      </div>
    )
  }
}