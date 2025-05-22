import scrapy
import datetime
from news_scraper.items import NewsItem

class HackerNewsSpider(scrapy.Spider):
    name = "hackernews"
    allowed_domains = ["news.ycombinator.com"]
    start_urls = ["https://news.ycombinator.com/"]

    def parse(self, response):
        for story in response.css('tr.athing'):
            item_id = story.attrib['id']
            title = story.css('span.titleline a::text').get()
            url = story.css('span.titleline a::attr(href)').get()
            
            # Get metadata from the next row
            meta_row = response.css(f'tr#{"" if not item_id else item_id} + tr')
            score = meta_row.css('span.score::text').get()
            author = meta_row.css('a.hnuser::text').get()
            
            # Create item
            item = NewsItem()
            item['title'] = title
            item['url'] = url
            item['author'] = author
            item['source'] = 'Hacker News'
            item['scraped_at'] = datetime.datetime.utcnow()
            
            yield item
            
        # Follow pagination
        next_page = response.css('a.morelink::attr(href)').get()
        if next_page:
            yield response.follow(next_page, self.parse)

class BBCNewsSpider(scrapy.Spider):
    name = "bbcnews"
    allowed_domains = ["bbc.com", "bbc.co.uk"]
    start_urls = ["https://www.bbc.com/news"]

    def parse(self, response):
        for article in response.css('div.gs-c-promo'):
            link = article.css('a.gs-c-promo-heading::attr(href)').get()
            if link and '/news/' in link:
                if not link.startswith('http'):
                    link = f"https://www.bbc.com{link}"
                yield response.follow(link, self.parse_article)
                
    def parse_article(self, response):
        title = response.css('h1::text').get()
        content = ' '.join(response.css('article p::text').getall())
        published_date = response.css('time::attr(datetime)').get()
        
        item = NewsItem()
        item['title'] = title
        item['url'] = response.url
        item['content'] = content
        item['published_date'] = published_date
        item['source'] = 'BBC News'
        item['scraped_at'] = datetime.datetime.utcnow()
        
        yield item
