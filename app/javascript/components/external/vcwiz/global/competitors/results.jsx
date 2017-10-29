import React from 'react';
import inflection from 'inflection';
import {CompetitorFundTypes, CompetitorIndustries, TargetInvestorsPath} from '../constants.js.erb';
import ResearchModal from './research_modal';
import WrappedTable from '../shared/wrapped_table';
import FixedTable from '../shared/fixed_table';
import {ffetch} from '../utils';

class ResultsTable extends FixedTable {
  defaultMiddleColumns() {
    return [
      { type: 'text_array', key: 'fund_type', name: 'Types', translate: CompetitorFundTypes },
      { type: 'text_array', key: 'location', name: 'Locations' },
      { type: 'text_array', key: 'industry', name: 'Industries', translate: CompetitorIndustries },
    ]
  }

  middleColumns() {
    const cols = this.props.columns || this.defaultMiddleColumns();
    const prefix = this.props.columns ? 'meta.' : '';
    return cols.map(({type, key, name, ...args}) => {
      let method = this[`render${inflection.camelize(type)}Column`];
      return method(`${prefix}${key}`, name, args);
    });
  }

  onTrackChange = (row, update) => {
    const id = this.props.array.getSync(row, false).target_investor.id;
    ffetch(TargetInvestorsPath.id(id), 'PATCH', update);
  };

  renderColumns() {
    return [
      this.renderImageTextColumn('name', 'Firm', { imageKey: 'photo', fallbackKey: 'acronym' }),
      this.middleColumns(),
      this.renderCompetitorTrackColumn('target_investor.stage', this.onTrackChange, 'Track'),
    ];
  }
}

export default class Results extends React.Component {
  render() {
    let { competitors, ...rest } = this.props;
    return (
      <WrappedTable
        items={competitors}
        modal={key => key !== 'track_status' && ResearchModal}
        table={ResultsTable}
        {...rest}
      />
    );
  }
}