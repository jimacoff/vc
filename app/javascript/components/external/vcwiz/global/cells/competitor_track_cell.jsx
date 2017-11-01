import React from 'react';
import TrackCell from './track_cell';
import {Button, Colors} from 'react-foundation';
import {nullOrUndef} from '../utils';

export default class CompetitorTrackCell extends TrackCell {
  onButtonClick = e => {
    this.props.onButtonClick(e, this.props.rowIndex);
  };

  renderValue() {
    if (!nullOrUndef(this.state.value)) {
      return super.renderValue();
    } else {
      return (
        <Button onClick={this.onButtonClick} color={Colors.SUCCESS} className="fake-track-button">
          ADD
        </Button>
      );
    }
  }
}