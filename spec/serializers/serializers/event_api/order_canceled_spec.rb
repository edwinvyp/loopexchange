# encoding: UTF-8
# frozen_string_literal: true

describe Serializers::EventAPI::OrderCanceled do
  let(:seller) { create(:member, :verified_identity, :barong) }

  let :order_ask do
    # Sell 100 BTC for 3 USD (0.03 USD per BTC).
    create :order_ask, \
      bid:           Currency.find_by!(code: :usd).id,
      ask:           Currency.find_by!(code: :btc).id,
      market:        Market.find(:btcusd),
      state:         :wait,
      source:        'Web',
      ord_type:      :limit,
      price:         '0.03'.to_d,
      volume:        '100.0',
      origin_volume: '100.0',
      locked:        '100.0',
      origin_locked: '100.0',
      member:        seller
  end

  subject { order_ask }

  let(:created_at) { 10.minutes.ago }
  let(:canceled_at) { Time.current }

  before do
    seller.ac(:btc).plus_funds('100.0'.to_d)
    seller.ac(:btc).lock_funds('100.0'.to_d)
  end

  before { OrderAsk.any_instance.expects(:created_at).returns(created_at).at_least_once }
  before { OrderAsk.any_instance.expects(:updated_at).returns(canceled_at).at_least_once }

  before do
    EventAPI.expects(:notify).with('market.btcusd.order_created', anything).once
    EventAPI.expects(:notify).with('market.btcusd.order_canceled', {
      market:                  'btcusd',
      type:                    'sell',
      trader_uid:              seller.uid,
      income_unit:             'usd',
      income_fee_type:         'relative',
      income_fee_value:        '0.0015',
      outcome_unit:            'btc',
      outcome_fee_type:        'relative',
      outcome_fee_value:       '0.0',
      initial_income_amount:   '3.0',
      current_income_amount:   '3.0',
      initial_outcome_amount:  '100.0',
      current_outcome_amount:  '100.0',
      strategy:                'limit',
      price:                   '0.03',
      state:                   'canceled',
      trades_count:            0,
      created_at:              created_at.iso8601,
      canceled_at:             canceled_at.iso8601
    }).once
  end

  it 'publishes event' do
    subject
    subject.transaction do
      subject.state = Order::CANCEL
      subject.hold_account.unlock_funds(subject.locked)
      subject.save!
    end
  end
end