import React from 'react';
import {FilterPath, SearchPath, CompetitorsFilterCountPath} from '../global/constants.js.erb';
import Tabs from '../global/tabs/tabs';
import FilterPage from '../filter/filter_page';
import inflection from 'inflection';

const MaxCount = 100;
const TabIndex = Object.freeze({
  FILTER: 0,
  SEARCH: 1,
});

export default class Hero extends React.Component {
  state = {
    query: '',
    count: 0,
    tab: 0,
  };

  onTabChange = tab => {
    this.setState({tab});
  };


  onQueryChange = (query, count) => {
    this.setState({query, count});
  };

  renderViewAll() {
    const { query, count } = this.state;
    const clipped = Math.min(count, MaxCount);
    const path = this.state.tab === TabIndex.FILTER ? FilterPath : SearchPath;
    return (
      <div className="view-all">
        <a href={`${path}?${query}`}>
          View
          {' '}
          {clipped !== 1 ? 'all' : null}
          {' '}
          {clipped && clipped !== MaxCount ? clipped : null}
          {' '}
          {clipped !== MaxCount ? inflection.inflect('results', clipped) : `${clipped}+ results`}
        </a>
      </div>
    );
  }

  renderBrowse() {
    return (
      <div>
        <FilterPage
          {...this.props}
          overwriteWithSavedFilters={true}
          showFilters={this.state.tab === TabIndex.FILTER}
          showSearch={this.state.tab === TabIndex.SEARCH}
          onQueryChange={this.onQueryChange}
          rowHeight={60}
          industryLimit={2}
          overflowY="hidden"
          render={(header, body) => (
            <div>
              {header}
              <div className="results">{body}</div>
            </div>
          )}
        />
        {this.renderViewAll()}
      </div>
    );
  }


  render() {
    return (
      <div className="search-hero">
        <div className="welcome">
          <h3><b>Discover Seed-Stage Investors</b></h3>
          <p>
            Lorem ipsum dolor sit amet, consectetur adipiscing elit.
            Aenean commodo viverra blandit. In hac habitasse platea dictumst.
            Etiam mattis placerat augue ut scelerisque. In eget ultricies ipsum
          </p>
        </div>
        <Tabs
          tabs={['Browse Investors', 'Find an Investor']}
          panels={[null, null]}
          onTabChange={this.onTabChange}
        />
        {this.renderBrowse()}
      </div>
    )
  }
}