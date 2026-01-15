# frozen_string_literal: true

require 'securerandom'
require 'stream-chat'
require 'time'

describe StreamChat::Campaign do
  def loop_times(times)
    loop do
      begin
        yield
        return
      rescue StandardError, RSpec::Expectations::ExpectationNotMetError
        raise if times.zero?
      end

      sleep(1)
      times -= 1
    end
  end

  before(:all) do
    @client = StreamChat::Client.from_env
    @created_users = []
    @created_campaigns = []
  end

  before(:each) do
    @random_users = [{ id: SecureRandom.uuid }, { id: SecureRandom.uuid }]
    @random_user = @random_users[0]

    @created_users.push(*@random_users.map { |u| u[:id] })
    @client.upsert_users(@random_users)
  end

  after(:each) do
    # Clean up campaigns created in tests
    @created_campaigns.each do |campaign_id|
      begin
        @client.delete_campaign(campaign_id)
      rescue StreamChat::StreamAPIException
        # Campaign may already be deleted, ignore
      end
    end
    @created_campaigns.clear
  end

  after(:all) do
    @users_to_delete = @created_users.dup
    curr_idx = 0
    batch_size = 25

    slice = @users_to_delete.slice(0, batch_size)

    while !slice.nil? && !slice.empty?
      begin
        @client.delete_users(slice, user: StreamChat::HARD_DELETE, messages: StreamChat::HARD_DELETE)
      rescue StreamChat::StreamAPIException
        # Users may already be deleted, ignore
      end

      curr_idx += batch_size
      slice = @users_to_delete.slice(curr_idx, batch_size)
    end
  end

  it 'can create campaign without id' do
    campaign = @client.campaign(
      data: {
        message_template: {
          text: 'Hello'
        },
        sender_id: @random_user[:id],
        user_ids: [@random_users[1][:id]],
        name: 'test campaign'
      }
    )
    expect(campaign.campaign_id).to eq nil

    created = campaign.create(
      data: {
        name: 'created name'
      }
    )
    expect(created.status_code).to be 201
    expect(created).to include 'campaign'
    expect(created['campaign']).to include 'id'
    expect(created['campaign']).to include 'name'
    expect(created['campaign']['name']).to eq 'created name'
    expect(campaign.campaign_id).not_to eq nil

    @created_campaigns << created['campaign']['id']
  end

  it 'can perform campaign CRUD operations' do
    sender_id = @random_user[:id]
    receiver_id = @random_users[1][:id]

    campaign = @client.campaign(
      data: {
        message_template: {
          text: 'Hello'
        },
        sender_id: sender_id,
        user_ids: [receiver_id],
        name: 'some name'
      }
    )

    # Create
    created = campaign.create(
      data: {
        name: 'created name'
      }
    )
    expect(created.status_code).to be 201
    expect(created).to include 'campaign'
    expect(created['campaign']).to include 'id'
    expect(created['campaign']).to include 'name'
    expect(created['campaign']['name']).to eq 'created name'
    campaign_id = created['campaign']['id']
    @created_campaigns << campaign_id

    # Read
    received = campaign.get
    expect(received.status_code).to be 200
    expect(received).to include 'campaign'
    expect(received['campaign']).to include 'id'
    expect(received['campaign']).to include 'name'
    expect(received['campaign']['name']).to eq 'created name'

    # Update
    updated = campaign.update(
      message_template: {
        text: 'Hello'
      },
      sender_id: sender_id,
      user_ids: [receiver_id],
      name: 'updated_name'
    )
    expect(updated.status_code).to be 200
    expect(updated).to include 'campaign'
    expect(updated['campaign']).to include 'id'
    expect(updated['campaign']).to include 'name'
    expect(updated['campaign']['name']).to eq 'updated_name'

    # Delete
    deleted = campaign.delete
    expect(deleted.status_code).to be 200
    @created_campaigns.delete(campaign_id)
  end

  it 'can start and stop campaign' do
    sender_id = @random_user[:id]
    receiver_id = @random_users[1][:id]

    campaign = @client.campaign(
      data: {
        message_template: {
          text: 'Hello'
        },
        sender_id: sender_id,
        user_ids: [receiver_id],
        name: 'some name'
      }
    )

    created = campaign.create
    expect(created.status_code).to be 201
    expect(created).to include 'campaign'
    expect(created['campaign']).to include 'id'
    expect(created['campaign']).to include 'name'
    campaign_id = created['campaign']['id']
    @created_campaigns << campaign_id

    # Start with scheduled times
    now = Time.now.utc
    one_hour_later = now + 3600
    two_hours_later = now + 7200

    started = campaign.start(scheduled_for: one_hour_later, stop_at: two_hours_later)
    expect(started.status_code).to be 201
    expect(started).to include 'campaign'
    expect(started['campaign']).to include 'id'
    expect(started['campaign']).to include 'name'

    # Stop
    stopped = campaign.stop
    expect(stopped.status_code).to be 201
    expect(stopped).to include 'campaign'
    expect(stopped['campaign']).to include 'id'
    expect(stopped['campaign']).to include 'name'

    # Clean up
    campaign.delete
    @created_campaigns.delete(campaign_id)
  end

  it 'can query campaigns' do
    sender_id = @random_user[:id]
    receiver_id = @random_users[1][:id]

    created = @client.create_campaign(
      data: {
        message_template: {
          text: 'Hello'
        },
        sender_id: sender_id,
        user_ids: [receiver_id],
        name: 'some name'
      }
    )
    expect(created.status_code).to be 201
    expect(created).to include 'campaign'
    expect(created['campaign']).to include 'id'
    expect(created['campaign']).to include 'name'
    campaign_id = created['campaign']['id']
    @created_campaigns << campaign_id

    query_campaigns = @client.query_campaigns(
      {
        'id' => {
          '$eq' => campaign_id
        }
      },
      sort: { 'created_at' => -1 },
      limit: 10
    )
    expect(query_campaigns.status_code).to be 201
    expect(query_campaigns).to include 'campaigns'
    expect(query_campaigns['campaigns'].length).to be >= 1
    found_campaign = query_campaigns['campaigns'].find { |c| c['id'] == campaign_id }
    expect(found_campaign).not_to be nil
    expect(found_campaign['id']).to eq campaign_id

    # Clean up
    @client.delete_campaign(campaign_id)
    @created_campaigns.delete(campaign_id)
  end

  it 'can use client methods directly' do
    sender_id = @random_user[:id]
    receiver_id = @random_users[1][:id]

    # Create using client method
    created = @client.create_campaign(
      data: {
        message_template: {
          text: 'Hello'
        },
        sender_id: sender_id,
        user_ids: [receiver_id],
        name: 'direct create'
      }
    )
    expect(created.status_code).to be 201
    campaign_id = created['campaign']['id']
    @created_campaigns << campaign_id

    # Get using client method
    got = @client.get_campaign(campaign_id)
    expect(got.status_code).to be 200
    expect(got['campaign']['id']).to eq campaign_id

    # Update using client method
    updated = @client.update_campaign(
      campaign_id,
      name: 'updated via client'
    )
    expect(updated.status_code).to be 200
    expect(updated['campaign']['name']).to eq 'updated via client'

    # Start using client method
    started = @client.start_campaign(campaign_id)
    expect(started.status_code).to be 201

    # Stop using client method
    stopped = @client.stop_campaign(campaign_id)
    expect(stopped.status_code).to be 201

    # Delete using client method
    deleted = @client.delete_campaign(campaign_id)
    expect(deleted.status_code).to be 201
    @created_campaigns.delete(campaign_id)
  end
end
