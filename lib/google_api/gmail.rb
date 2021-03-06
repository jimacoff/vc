require 'google/apis/gmail_v1'

module GoogleApi
  class Gmail < Base
    SCOPES = [Google::Apis::GmailV1::AUTH_GMAIL_READONLY]

    def initialize(user, skip_graph: false)
      @user = user
      @skip_graph = skip_graph
      @gmail = Google::Apis::GmailV1::GmailService.new
      @gmail.authorization = authorization
      @gmail.quota_user = @user.id.to_s
      @gmail.user_ip = @user.ip_address.to_s
    end

    def sync!
      if @user.history_id.present?
        sync_partial!
      else
        sync_full!
      end
    rescue Signet::AuthorizationError, Google::Apis::ClientError => e
      Rails.logger.warn e
    rescue Google::Apis::AuthorizationError
      @user.update! history_id: nil
      FounderMailer.bad_link_email(@user).deliver_later
    end

    def backfill!(oldest, newest)
      sync_range! oldest, newest, track: false
    rescue => e
      Rails.logger.warn e
    end

    private

    def sync_partial!
      begin
        response = list_histories
      rescue Google::Apis::ClientError
        @skip_graph ||= @user.history_id != 0
        sync_full!
        return
      end

      loop do
        break unless response.history.present?
        message_ids = response.history.flat_map do |history|
          history.messages_added.reject { |ma| ma.message.label_ids&.include?('DRAFT') }.map { |ma| ma.message.id }
        end.uniq
        get_messages(message_ids) do |message|
          process_message message
        end if message_ids.present?
        @user.update! history_id: response.history_id
        break unless response.next_page_token.present?
        response = list_histories response.next_page_token
      end
    end

    def sync_full!
      sync_range! '2y', nil
    end

    def sync_range!(oldest, newest, track: true)
      response = list_threads(oldest: oldest, newest: newest)
      history_id = response.threads.first.history_id
      loop do
        thread_ids = response.threads.map(&:id)
        get_threads(thread_ids)  do |thread|
          process_thread thread
        end if thread_ids.present?
        break unless response.next_page_token.present?
        response = list_threads(response.next_page_token, oldest: oldest, newest: newest)
      end
      @user.update! history_id: history_id if track
    end

    def process_thread(thread)
      thread.messages.last(2).each do |message|
        process_message(message)
      end
    end

    def process_message(message)
      return unless message.present?
      Message.new(message).process!(@user, @skip_graph)
    end

    %w(thread message).each do |s|
      define_method("get_#{s}s") do |ids, &block|
        @gmail.batch do |batch|
          ids.each do |id|
            batch.public_send("get_user_#{s}", @user.email, id) do |res, err|
              if err.present?
                if err.is_a? Google::Apis::ClientError
                  Rails.logger.warn err
                else
                  raise err
                end
              else
                block.call(res)
              end
            end
          end
        end
      end
    end

    def list_histories(token = nil)
      @gmail.list_user_histories(@user.email, history_types: 'messageAdded', start_history_id: @user.history_id, page_token: token)
    end

    def list_threads(token = nil, oldest: nil, newest: nil)
      q = [
        oldest.present? ? "newer_than:#{oldest}" : nil,
        newest.present? ? "older_than:#{newest}" : nil,
      ].compact.join(' ')
      @gmail.list_user_threads(@user.email, page_token: token, q: q)
    end
  end
end
