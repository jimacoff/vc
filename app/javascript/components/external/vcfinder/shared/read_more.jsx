import React  from 'react';
import Truncate from 'react-truncate';

export default class ReadMore extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      expanded: false,
      loaded: false,
    };
  }

  handleTruncate = (truncated) => {
    if (this.state.truncated !== truncated) {
      this.setState({truncated});
    }
  };

  toggleLines = (event) => {
    event.preventDefault();
    this.setState({expanded: !this.state.expanded});
  };

  renderLess() {
    const {less} = this.props;
    const {expanded, truncated} = this.state;
    if (!truncated && expanded) {
      return  <span> <a href='#' onClick={this.toggleLines}>{less}</a></span>;
    } else {
      return null;
    }
  }

  render() {
    const {children, more, lines} = this.props;
    const {expanded} = this.state;

    return (
      <span>
        <Truncate
          lines={!expanded && lines}
          ellipsis={<span>.. <a href='#' onClick={this.toggleLines}>{more}</a></span>}
          onTruncate={this.handleTruncate}
        >
          {children}
        </Truncate>
        {this.renderLess()}
      </span>
    );
  }
}

ReadMore.defaultProps = {
  lines: 7,
  more: 'more',
  less: 'less'
};