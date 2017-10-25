import React from 'react';
import OverlayModal from '../shared/overlay_modal';
import ProfileImage from '../shared/profile_image';
import {CompetitorFundTypes, CompetitorIndustries} from '../constants.js.erb';
import {Row, Column} from 'react-foundation';
import { Tab, Tabs, TabList, TabPanel } from 'react-tabs';
import {fullName, withDots} from '../utils';
import PartnerTab from './partner_tab';
import IconLine from '../shared/icon_line';
import showdown from 'showdown';

export default class ResearchModal extends OverlayModal {
  constructor(props) {
    super(props);
    this.converter = new showdown.Converter();
  }


  renderHeading() {
    const { name, photo, hq, fund_type } = this.props;
    return (
      <div>
        <ProfileImage src={photo} size={50} className="inline-image" />
        <div className="heading">{name}</div>
        <div className="subheading">
          <span>{CompetitorFundTypes[_.first(fund_type)]}</span>
          <span>·</span>
          <span>{hq}</span>
        </div>
      </div>
    );
  }

  renderCompany({ crunchbase_id, domain, name }) {
    let url =
      (domain && `http://${domain}`) ||
      (crunchbase_id && `https://www.crunchbase.com/organization/${crunchbase_id}`);
    return url ? <a href={url} target="_blank">{name}</a> : name;
  }

  renderIndustries() {
    const { industry } = this.props;
    if (!industry || !industry.length) {
      return null;
    }
    let industries = industry.map(i =>
      <span key={i}>{CompetitorIndustries[i]}</span>
    );
    return <p><b>Top Industries</b>: {withDots(industries)}</p>
  }

  renderInvestments() {
    const { recent_investments } = this.props;
    if (!!recent_investments.length) {
      return null;
    }
    let investments = recent_investments.map(c =>
      <span key={c.id}>{this.renderCompany(c)}</span>
    );
    return <p><b>Recent Investments</b>: {withDots(investments)}</p>
  }

  renderCompetitorInfo() {
    const { description } = this.props;

    return (
      <div className="competitor-info">
        <p className="description" dangerouslySetInnerHTML={{ __html: this.converter.makeHtml(description) }} />
        {this.renderIndustries()}
        {this.renderInvestments()}
      </div>
    );
  }

  renderIconLine(icon, line, link = null, text = null) {
    return <IconLine icon={icon} line={line} link={link} text={text}/>;
  }

  renderCompetitorSocial() {
    let { al_url, cb_url, crunchbase_id, facebook, twitter, domain } = this.props;
    return (
      <div className="competitor-social">
        {this.renderIconLine('list', '', al_url, 'angel.co')}
        {this.renderIconLine('info', '', cb_url, crunchbase_id)}
        {this.renderIconLine('web', domain, 'http://')}
        {this.renderIconLine('social-facebook', facebook, 'https://fb.com')}
        {this.renderIconLine('social-twitter', twitter && `@${twitter}`, 'https://twitter.com')}
      </div>
    )
  };

  renderPartners() {
    let { partners, matches } = this.props;
    let defaultIndex = _.findIndex(partners, {id: _.first(matches)});
    if (defaultIndex === -1) {
      defaultIndex = undefined;
    }
    return (
      <Tabs selectedTabPanelClassName="tab-panel" defaultIndex={defaultIndex}>
        <div className="tab-list-wrapper">
          <TabList className="tab-list">
            {partners.map(p => <Tab key={p.id}>{fullName(p)}</Tab>)}
          </TabList>
        </div>
        {partners.map(p => <TabPanel key={p.id}><PartnerTab {...p} /></TabPanel>)}
      </Tabs>
    );
  }

  renderBottom() {
    if (!this.props.partners) {
      return null;
    }
    return (
      <div className="research-modal-bottom">
        {this.renderPartners()}
      </div>
    );
  }

  renderModal() {
    return (
      <div className="research-modal">
        <div className="research-modal-top">
          <Row>
            <Column large={9}>
              {this.renderHeading()}
              {this.renderCompetitorInfo()}
            </Column>
            <Column large={2} offsetOnLarge={1}>
              {this.renderCompetitorSocial()}
            </Column>
          </Row>
        </div>
        {this.renderBottom()}
      </div>
    )
  }
}