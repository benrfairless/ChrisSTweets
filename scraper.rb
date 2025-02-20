# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

# require 'scraperwiki'
# require 'mechanize'
#
# agent = Mechanize.new
#
# # Read in a page
# page = agent.get("http://foo.com")
#
# # Find something on the page using css selectors
# p page.at('div.content')
#
# # Write out to the sqlite database using scraperwiki library
# ScraperWiki.save_sqlite(["name"], {"name" => "susan", "occupation" => "software developer"})
#
# # An arbitrary query against the database
# ScraperWiki.select("* from data where 'name'='peter'")

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".

require 'scraperwiki'
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'yaml'
require 'date'
require 'sanitize'

username = 'ChrisSAustDems'

uri = URI.parse(ARGV[0] || "https://www.x.com/#{username}")
http = Net::HTTP.new(uri.host, uri.port)
http.use_ssl = true
http.verify_mode = OpenSSL::SSL::VERIFY_NONE
http.start {
  http.request_get(uri.path) {|res|
    body = res.body
  }
}

doc = Nokogiri.HTML(body)

tweets = doc.search('.stream-item')

# If the table doesn't exist, create it (trust me on this one!)
ScraperWiki.select("* from data") rescue ScraperWiki.sqliteexecute('CREATE TABLE `data` (`time` text, `permalink` text, `tweet` text,`tweettext` text, `lat` real, `lng` real)')
ScraperWiki.select("* from metadata") rescue ScraperWiki.sqliteexecute('CREATE TABLE `metadata` (`username` text, `name` text)')

meta = {}
meta[:username] = username
meta[:name] = doc.search('h1.fullname')[0].inner_text
ScraperWiki::save_sqlite([:username], meta, table_name="metadata", verbose=2)

tweets.each do |tweet|
  
  details = {}
  details[:time] = DateTime.strptime(tweet.search('._timestamp')[0]["data-time"], '%s')
  details[:permalink] = "http://www.x.com" + tweet.search('.tweet-timestamp')[0][:href]
  
  source = tweet.search('.username b')[0].inner_text.strip
  tweet_content = Sanitize.clean(tweet.search('.js-tweet-text')[0].inner_html.strip, :elements => ['a'], :attributes => {'a' => ['href']}).gsub("href=\"/", "href=\"http://www.twitter.com/")

  if source.downcase != username.downcase
    # This is a retweet
    details[:tweet] = "RT <a href=\"http://x.com/#{source}\">@#{source}</a> " + tweet_content
  else
    details[:tweet] = tweet_content
  end

  if tweet.search('.sm-geo').length > 0
    latlng = tweet.search('.tweet')[0]["data-expanded-footer"].scan(/maps.google.com\/maps\?q=(-?[0-9]+.[0-9]+)%2C(-?[0-9]+.[0-9]+)/)[0]
    details[:lat] = latlng[0]
    details[:lng] = latlng[1]
  end

  details[:tweettext] = Nokogiri::HTML(details[:tweet]).inner_text

  ScraperWiki.save([:permalink], details)

end
