import scrapy

class NewsItem(scrapy.Item):
    title = scrapy.Field()
    url = scrapy.Field()
    content = scrapy.Field()
    author = scrapy.Field()
    published_date = scrapy.Field()
    source = scrapy.Field()
    scraped_at = scrapy.Field()