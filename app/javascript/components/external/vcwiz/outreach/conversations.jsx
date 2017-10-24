import React from 'react';
import WrappedTable from '../global/shared/wrapped_table';
import ResearchModal from '../global/competitors/research_modal';
import EmojiModal from './emoji_modal';
import FixedTable from '../global/shared/fixed_table';
import {initials} from '../global/utils';

class ConversationsTable extends FixedTable {
  renderColumns() {
    return [
      this.renderImageTextColumn('name', 'Partner', { imageKey: 'investor.photo', fallbackFn: initials, subKey: 'title', max: 18 }, 2),
      this.renderIntroColumn('intro_request', 'VCWiz Intro', { eligibleKey: 'can_intro?' }),
      this.renderTrackColumn('stage', 'Stage'),
      this.renderEmojiColumn('priority', <div className="emoji-button">‼</div>),
      this.renderTextColumn('note', 'Notes', 2),
      this.renderDatetimeColumn('last_response', 'Last Interaction'),
    ]
  }
}

export default class Conversations extends React.Component {
  render() {
    let { targets, ...props } = this.props;
    return (
      <WrappedTable
        items={targets}
        modal={{
          name: ResearchModal,
          priority: EmojiModal,
        }}
        table={ConversationsTable}
        {...props}
      />
    );
  }
}