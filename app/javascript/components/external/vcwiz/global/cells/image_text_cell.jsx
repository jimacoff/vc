import React from 'react';
import TextCell from './text_cell';
import {Textfit} from 'react-textfit';
import ProfileImage from '../shared/profile_image';

export default class ImageTextCell extends TextCell {
  processRow(props, row) {
    return {
      value: _.get(row, props.columnKey),
      subValue: _.get(row, props.subKey),
      src: _.get(row, props.imageKey),
      fallback: props.fallbackFn ? props.fallbackFn(row) : row[props.fallbackKey],
    };
  };

  placeholderProps() {
    return {
      ...super.placeholderProps(),
      type: 'media',
      rows: 2,
    };
  }

  renderImage() {
    return (
      <ProfileImage
        src={this.state.src}
        fallback={this.state.fallback}
        size={this.props.size}
        className="floating-image"
      />
    );
  }

  renderValue() {
    return (
      <div className="image-text-cell">
        {this.renderImage()}
        <div className="image-text">
          <Textfit mode="single" min={this.props.min} max={this.props.max}>
            <div className="textfit-cell">
              {this.state.value}
              <div className="subheading">{this.state.subValue}</div>
            </div>
          </Textfit>
        </div>
      </div>
    )
  }
}