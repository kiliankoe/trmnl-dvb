# frozen_string_literal: true

require 'json'

RSpec.describe 'DVB Departures' do
  let(:departures) { JSON.parse(File.read(File.join(__dir__, 'fixtures/albertplatz.json'))) }
  let(:mocks) { { 'https://webapi.vvo-online.de/dm?stopid=33000013*' => { json: departures } } }
  let(:custom_fields) { { 'stop_id' => '33000013' } }
  # Captured response starts at 09:02 UTC; Dresden is UTC+2 on this date.
  let(:now) { '2026-10-07T09:00:00Z' }
  let(:variables) { { trmnl: { user: { utc_offset: 7200 } } } }

  def render(**opts) = trmnl.render(mocks:, custom_fields:, now:, variables:, **opts)

  it_behaves_like 'a publishable recipe'

  describe 'grouped view' do
    subject(:screen) { render }

    it 'names the stop' do
      expect(screen).to have_css('.title_bar', text: 'Albertplatz')
      expect(screen).to have_no_css('.title_bar', text: 'walk')
    end

    it 'shows one row per line and direction with its upcoming times' do
      group = screen.find('.group', text: 'Wilder Mann')
      expect(group).to have_css('.line', text: '3')
      expect(group).to have_text('11:06')
      expect(group).to have_text('11:12')
      expect(group).to have_text('11:22')
      expect(screen).to have_css('.group', text: 'Wilder Mann', count: 1)
    end

    it 'orders rows by their soonest departure' do
      directions = screen.all('.group .direction').map(&:text)
      expect(directions.first(2)).to eq(['Wilder Mann', 'Zschertnitz'])
    end

    it 'fits long line names into the badge' do
      spill = screen.evaluate(<<~JS)
        [...document.querySelectorAll('.line')].filter(b => b.firstElementChild.scrollWidth > b.clientWidth).map(b => b.textContent.trim())
      JS
      expect(screen).to have_css('.line', text: 'RJ 382')
      expect(spill).to be_empty
    end

    it 'keeps directions apart when one is empty' do
      blank = departures['Departures'].map { it['Direction'] == 'Coschütz' ? it.merge('Direction' => '') : it }
      screen = render(mocks: { '*' => { json: departures.merge('Departures' => blank) } })
      expect(screen).to have_css('.group', text: '11:06', count: 1)
    end

    it 'strikes through cancelled times' do
      expect(screen.find('.group', text: 'Coschütz')).to have_css('s', text: '11:08')
    end

    it 'spreads many groups over two columns' do
      expect(screen).to have_css('.column', count: 2)
      expect(screen).to have_no_overflow
    end

    it 'hides departures that leave before the walking time is up' do
      screen = render(custom_fields: custom_fields.merge('walk_minutes' => '7'))
      group = screen.find('.group', text: 'Wilder Mann')
      expect(group).to have_no_text('11:06')
      expect(group).to have_text('11:12')
      expect(screen).to have_css('.title_bar', text: '7 min walk')
    end

    it 'keeps a few groups in one column' do
      few = departures.merge('Departures' => departures['Departures'].first(3))
      screen = render(mocks: { '*' => { json: few } })
      expect(screen).to have_css('.column', count: 1)
    end
  end

  describe 'list view' do
    subject(:screen) { render(custom_fields: custom_fields.merge('view' => 'list')) }

    it 'shows real-time departure times in local time with the delay' do
      row = screen.find('.departure', match: :first)
      expect(row).to have_text('11:06')
      expect(row).to have_text('+4')
      expect(row).to have_text('3')
      expect(row).to have_text('Wilder Mann')
    end

    it 'strikes through cancelled departures without a delay' do
      row = screen.find('.departure', text: 'Coschütz', match: :first)
      expect(row).to have_css('s', text: '11:08')
      expect(row).to have_no_text('+')
    end

    it 'also treats departures with cancel reasons as cancelled' do
      expect(screen).to have_css('.departure s', text: '11:12')
    end

    it 'falls back to the scheduled time without a delay when there is no real-time data' do
      row = screen.find('.departure', text: 'Wölfnitz', match: :first)
      expect(row).to have_text('11:09')
      expect(row).to have_no_text('+')
    end

    it 'applies the walking time to real-time departures and falls back to the scheduled time' do
      screen = render(custom_fields: custom_fields.merge('view' => 'list', 'walk_minutes' => '8'))
      expect(screen.find('.departure', text: 'Niedersedlitz', match: :first)).to have_text('11:20')
      expect(screen.find('.departure', text: 'Wölfnitz', match: :first)).to have_text('11:09')
    end

    it 'fills two columns' do
      expect(screen).to have_css('.column', count: 2)
      expect(screen).to have_no_overflow
    end

    it 'clamps long directions within the column' do
      long = departures['Departures'].first.merge('LineName' => '226', 'Direction' => 'Pirna R.-Koch-Str. üb. Dürrröhrsdorf')
      data = departures.merge('Departures' => [long] + departures['Departures'])
      screen = render(custom_fields: custom_fields.merge('view' => 'list'), mocks: { '*' => { json: data } })
      expect(screen).to have_no_overflow
    end
  end

  it 'shows the API error instead of an empty board, since a misconfigured stop ID is the usual cause' do
    error = { 'Status' => { 'Code' => 'ValidationError', 'Message' => 'stopid has to be a number' } }
    screen = render(mocks: { '*' => { json: error } })
    expect(screen).to have_text('stopid has to be a number')
  end
end
