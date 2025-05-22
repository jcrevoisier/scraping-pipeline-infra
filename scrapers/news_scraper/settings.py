BOT_NAME = 'news_scraper'

SPIDER_MODULES = ['news_scraper.spiders']
NEWSPIDER_MODULE = 'news_scraper.spiders'

# Obey robots.txt rules
ROBOTSTXT_OBEY = True

# Configure maximum concurrent requests
CONCURRENT_REQUESTS = 16

# Configure a delay for requests for the same website
DOWNLOAD_DELAY = 1

# Enable or disable downloader middlewares
DOWNLOADER_MIDDLEWARES = {
   'news_scraper.middlewares.NewsScraperDownloaderMiddleware': 543,
}

# Enable or disable spider middlewares
SPIDER_MIDDLEWARES = {
   'news_scraper.middlewares.NewsScraperSpiderMiddleware': 543,
}

# Configure item pipelines
ITEM_PIPELINES = {
   'news_scraper.pipelines.PostgresPipeline': 300,
   'news_scraper.pipelines.JsonWriterPipeline': 800,
   'scrapy_prometheus.pipelines.PrometheusPipeline': 900,
}

# Enable and configure the Prometheus extension
PROMETHEUS_ENABLED = True
PROMETHEUS_PORT = [9410]
PROMETHEUS_HOST = '0.0.0.0'
PROMETHEUS_NAMESPACE = 'news_scraper'
PROMETHEUS_PATH = 'metrics'

# Set settings whose default value is deprecated to a future-proof value
REQUEST_FINGERPRINTER_IMPLEMENTATION = "2.7"
TWISTED_REACTOR = "twisted.internet.asyncioreactor.AsyncioSelectorReactor"
FEED_EXPORT_ENCODING = "utf-8"
