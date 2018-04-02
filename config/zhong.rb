require_relative './boot'
require_relative './environment'

Zhong.redis = Redis.new(url: ENV['REDIS_URL'])

Zhong.schedule do
  if Rails.application.drfvote?
    category 'sync' do
      every(1.hour, 'list') { List.sync! }
      every(15.minutes, 'company.shallow') { Company.sync!(quiet: false, deep: false) }
      every(1.day, 'company.deep', at: '00:00') { Company.sync!(quiet: false, deep: true) }
      every(1.hour, 'evergreen') { Slack::CollectEvergreensJob.perform_later }
    end

    category 'cache' do
      every(1.day, 'warm', at: '08:00') { CacheWarmJob.perform_later }
    end

    category 'pitch' do
      every(10.minutes, 'notify') { CompanyPrepareJob.perform_later }
    end

    category 'monitor' do
      every(1.day, 'user', at: '08:00') { UserMonitorJob.perform_later }
      every(1.day, 'application', at: '08:00') { ApplicationMonitorJob.perform_later }
      every(1.day, 'card', at: '09:00') { CardMonitorJob.perform_later }
      every(1.minute, 'vote') { VoteMonitorJob.perform_later }
      every(1.hour, 'news') { CompanyNewsJob.perform_later }
    end

    category 'users' do
      every(15.minutes, 'calendar') { UserCalendarJob.perform_later }
    end
  end
  if Rails.application.vcwiz?
    category 'crawl' do
      every(4.days, 'investors.posts', at: '01:00') { CrawlPostsJob.perform_later }
      every(4.hours, 'investors.tweets', skip_first_run: true) { CrawlTweetsJob.perform_later }
      every(2.days, 'refresh', at: '02:00') { RefreshJob.perform_later }
    end

    category 'vcwiz' do
      every(1.weeks, 'summaries', at: 'Sunday 17:30') { FounderSummaryJob.perform_later }
      every(1.day, 'industry', at: '00:00') { PropagateIndustryJob.perform_later }
      every(1.day, 'clean', at: '01:00') { CompanyCleanJob.perform_later }
      every(1.day, 'graph_bulk', at: '02:00') { GraphBulkJob.perform_later(shallow: true) }
      every(12.hours, 'gmail',  skip_first_run: true) { FoundersGmailSyncJob.perform_later }
      every(1.hours, 'investors',  skip_first_run: true) { FindInvestorsJob.perform_later }
      every(3.hours, 'competitor_lists',  skip_first_run: true) { CompetitorListJob.perform_later }
      every(1.hours, 'refresh_views') { RefreshJob.perform_later(only_views: true) }
    end

    category 'bulk' do
      every(1.month, 'crunchbase') { CrunchbasePullJob.perform_later }
      every(1.week, 'founder.companies') { FounderCompanyRefreshJob.perform_later }
    end
  end
end
