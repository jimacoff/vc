import React from 'react';
import WrappedTable from '../global/shared/wrapped_table';
import EmojiModal from './emoji_modal';
import PartnerModal from './partner_modal';
import FixedTable from '../global/shared/fixed_table';
import {initials, ffetch} from '../global/utils';
import {TargetInvestorsPath} from '../global/constants.js.erb';
import Actions from '../global/actions';

class ConversationsTable extends FixedTable {
  onTrackChange = (row, update) => {
    const id = this.props.array.getSync(row, false).id;
    ffetch(TargetInvestorsPath.id(id), 'PATCH', {target_investor: update}).then(() => {
      Actions.trigger('refreshFounder');
    });
  };

  renderColumns() {
    return [
      this.renderImageTextColumn('full_name', 'Partner', { imageKey: 'investor.photo', fallbackFn: initials, subKey: 'title', max: 18 }, 2),
      this.renderTrackColumn('stage', this.onTrackChange, 'Stage'),
      this.renderIntroColumn('intro_requests[0]', 'VCWiz Intro', { eligibleKey: 'can_intro?', emailKey: 'email_present?', stageKey: 'stage' }),
      this.renderEmojiColumn('priority', 'Tag'),
      this.renderPlaceholderColumn('note', 'Notes', 2),
      this.renderDatetimeColumn('last_response', 'Last Response'),
    ]
  }
}

export default class Conversations extends React.Component {
  render() {
    let { targets, ...rest } = this.props;
    return (
      <WrappedTable
        items={targets}
        modal={{
          full_name: PartnerModal,
          priority: EmojiModal,
        }}
        table={ConversationsTable}
        {...rest}
      />
    );
  }
}