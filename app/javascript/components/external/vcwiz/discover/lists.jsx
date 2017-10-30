import React from 'react';
import { CompetitorsListsPath, ListPath } from '../global/constants.js.erb'
import { ffetchCached } from '../global/utils';
import ProfileImage from '../global/shared/profile_image';
import {Row, Column} from 'react-foundation';
import Loader from '../global/shared/loader';

export default class Lists extends React.Component {
  constructor(props) {
    super(props);

    this.state = {
      loading: true,
      lists: [],
    };
  }

  componentDidMount() {
    ffetchCached(CompetitorsListsPath).then(lists => {
      this.setState({lists, loading: false});
    });
  }

  profileImageProps() {
    return {
      className: 'inline-image',
      size: 40,
      background: 'FFFFFF',
      foreground: '000000',
    };
  }

  onListClick = name => () => {
    window.location.href = `${ListPath.id(name)}`;
  };

  renderLoading() {
    return (
      <div className="text-center loading">
        <Loader color="#2ADBC4" size={200} />
      </div>
    );
  }

  renderCount(count) {
    return <ProfileImage fallback={`+${count}`} {...this.profileImageProps()} />;
  }

  renderCompetitor = ({id, photo, acronym}) => {
    return (
      <ProfileImage
        key={id}
        src={photo}
        fallback={acronym}
        {...this.profileImageProps()}
      />
    );
  };

  renderList = ({title, name, competitors, count}, i, arr) => {
    let displayCompetitors = _.take(competitors, 5);
    return (
      <Column large={4} key={name} isLast={i === arr.length - 1}>
        <div className="card-wrapper">
          <div className="card" onClick={this.onListClick(name)}>
            <div className="card-section">
              <p className="title">{title}</p>
              <div className="body">
                <h6>Investors</h6>
                <div>
                  {displayCompetitors.map(this.renderCompetitor)}
                  {this.renderCount(count - displayCompetitors.length)}
                </div>
              </div>
            </div>
          </div>
        </div>
      </Column>
    );
  };

  renderListGroup = (group, i) => {
    return (
      <Row key={i}>
        {group.map(this.renderList)}
      </Row>
    );
  };

  renderLists() {
    return (
      <div className="cards">
        {_.chunk(this.state.lists, 3).map(this.renderListGroup)}
      </div>
    );
  }

  render() {
    if (this.state.loading) {
      return this.renderLoading();
    } else {
      return this.renderLists();
    }
  }
}