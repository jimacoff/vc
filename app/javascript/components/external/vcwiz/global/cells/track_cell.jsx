import React from 'react';
import {UnpureTextCell} from './text_cell';
import Track from '../fields/track';
import Store from '../store';
import {TargetInvestorsPath} from '../constants.js.erb';

export default class TrackCell extends UnpureTextCell {
  processRow(props, row) {
    return {id: row.id, value: props.data};
  };

  componentWillMount() {
    this.subscription = Store.subscribe('founder', ({target_investors}) => {
      if (!this.state.id) {
        return;
      }
      const target = _.find(target_investors, {id: this.state.id});
      this.setState({value: _.get(target, this.props.columnKey)});
    });
  }

  componentWillUnmount() {
    Store.unsubscribe(this.subscription);
  }

  renderValue() {
    return (
      <div className='track-cell'>
        <Track
          name={this.props.columnKey}
          value={this.state.value}
          onChange={this.onChange}
        />
      </div>
    )
  }
}