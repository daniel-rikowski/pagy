# frozen_string_literal: true

# Self-contained sinatra app to test the pagy helpers in the browser

# TEST USAGE:
#    rackup -o 0.0.0.0 -p 4567 e2e/pagy_app.ru

# DEV USAGE:
#    rerun -- rackup -o 0.0.0.0 -p 4567 e2e/pagy_app.ru

# Available at http://0.0.0.0:4567

require 'bundler'
Bundler.require(:default, :apps)
require 'oj' # require false in Gemfile

$LOAD_PATH.unshift File.expand_path('../gem/lib', __dir__)
require 'pagy'

# pagy initializer
require 'pagy/extras/calendar'  # must be loaded before the frontend extras

STYLES = %w[bootstrap bulma foundation materialize pagy semantic uikit].freeze
STYLES.each { |style| require "pagy/extras/#{style}" }
require 'pagy/extras/items'
require 'pagy/extras/trim'
Pagy::DEFAULT[:size]       = [1, 4, 4, 1]  # old size default
Pagy::DEFAULT[:trim_extra] = false         # opt-in trim

# simple array-based collection that acts as standard DB collection
require_relative '../test/mock_helpers/collection'

# sinatra setup
require 'sinatra/base'

# sinatra application
class PagyApp < Sinatra::Base
  PAGY_JS = "pagy#{'-dev' if ENV['DEBUG']}.js".freeze

  configure do
    enable :inline_templates
  end

  include Pagy::Backend

  helpers do
    include Pagy::Frontend

    def site_map
      html = +%(<div id="site-map">| )
      [:home, *STYLES].each do |style|
        html << %(<a href="/#{style}">#{style}</a>)
        html << %(-<a href="/#{style}-calendar">cal</a>) unless style == :home
        html << %( | )
      end
      html << %(</div>)
    end
  end

  def pagy_calendar_period(collection)
    collection.minmax
  end

  def pagy_calendar_filter(collection, from, to)
    collection.select_page_of_records(from, to)  # storage in UTC
  end

  get("/#{PAGY_JS}") do
    content_type 'application/javascript'
    send_file Pagy.root.join('javascripts', PAGY_JS)
  end

  %w[/ /home].each do |route|
    get(route) { erb :home }
  end

  # one route/action per style
  STYLES.each do |style|
    prefix = style == 'pagy' ? '' : "_#{style}"

    get("/#{style}-calendar/?:trim?") do
      collection = MockCollection::Calendar.new
      @calendar, @pagy, @records = pagy_calendar(collection, month: { size: [1, 2, 2, 1],
                                                                      format: '%Y-%m',
                                                                      trim_extra: params['trim'] })
      erb :calendar_helpers, locals: { style:, prefix: }
    end

    get("/#{style}/?:trim?") do
      collection = MockCollection.new
      @pagy, @records = pagy(collection, trim_extra: params['trim'])
      erb :helpers, locals: { style:, prefix: }
    end
  end
end

run PagyApp

__END__

@@ layout
<html lang="en">
<head>
  <title>Pagy E2E</title>
  <script src="<%= %(/#{PAGY_JS}) %>"></script>
  <script>
    window.addEventListener("load", Pagy.init);
  </script>
  <link rel="stylesheet" href="/normalize-styles.css">
</head>
<body>
  <%= yield %>
  <%= site_map %>
</body>
</html>



@@ home
<div id="home">
  <h1>Pagy e2e app</h1>

  <p>This app runs on Sinatra/Puma and is used for testing locally and in GitHub Actions CI with cypress, or just inspect the different helpers in the same page.</p>

  <p>It shows all the helpers for all the styles supported by pagy.</p>

  <p>Each framework provides its own set of CSS that applies to the helpers, but we cannot load different frameworks in the same app because they would conflict. Without the framework where the helpers are supposed to work we can only normalize the CSS styles in order to make them at least readable.</p>
  <hr>
</div>



@@ helpers
<h1 id="style"><%= style %></h1>
<hr>

<p>@records</p>
<p id="records"><%= @records.join(',') %></p>
<hr>

<p>pagy_info</p>
<%= pagy_info(@pagy, id: 'pagy-info') %>
<hr>

<p>pagy_items_selector_js</p>
<%= pagy_items_selector_js(@pagy, id: 'items-selector-js') %>
<hr>

<p><%= "pagy#{prefix}_nav" %></p>
<%= send(:"pagy#{prefix}_nav", @pagy, id: 'nav', aria_label: 'Pages nav') %>
<hr>

<p><%= "pagy#{prefix}_nav_js" %></p>
<%= send(:"pagy#{prefix}_nav_js", @pagy, id: 'nav-js', aria_label: 'Pages nav_js') %>
<hr>

<p><%= "pagy#{prefix}_nav_js" %> (responsive)</p>
<%= send(:"pagy#{prefix}_nav_js", @pagy, id: 'nav-js-responsive',
         aria_label: 'Pages nav_js_responsive',
         steps: { 0 => [1,3,3,1], 600 => [2,4,4,2], 900 => [3,4,4,3] }) %>
<hr>

<p><%= "pagy#{prefix}_combo_nav_js" %></p>
<%= send(:"pagy#{prefix}_combo_nav_js", @pagy, id: 'combo-nav-js', aria_label: 'Pages combo_nav_js') %>
<hr>



@@ calendar_helpers
<h1 id="style"><%= style %> (calendar)</h1>
<hr>

<p>@records</p>
<div id="records"><%= @records.join(' | ') %></div>
<hr>

<p><%= "pagy#{prefix}_nav" %></p>
<%= send(:"pagy#{prefix}_nav", @calendar[:month], id: 'nav',
         aria_label: 'Pages nav') %>
<hr>

<p><%= "pagy#{prefix}_nav_js" %></p>
<%= send(:"pagy#{prefix}_nav_js", @calendar[:month], id: 'nav-js',
         aria_label: 'Pages nav_js') %>
<hr>

<p><%= "pagy#{prefix}_nav_js" %> (responsive)</p>
<%= send(:"pagy#{prefix}_nav_js", @calendar[:month], id: 'nav-js-responsive',
         aria_label: 'Pages combo_nav_js',
         steps: { 0 => [1,3,3,1], 600 => [2,4,4,2], 900 => [3,4,4,3] }) %>
<hr>
