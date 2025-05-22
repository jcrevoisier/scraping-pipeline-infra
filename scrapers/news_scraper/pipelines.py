import datetime
import json
import os
from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker

Base = declarative_base()

class NewsArticle(Base):
    __tablename__ = 'news_articles'

    id = Column(Integer, primary_key=True)
    title = Column(String(255))
    url = Column(String(255), unique=True)
    content = Column(Text)
    author = Column(String(100))
    published_date = Column(String(50))
    source = Column(String(100))
    scraped_at = Column(DateTime, default=datetime.datetime.utcnow)

class PostgresPipeline:
    def __init__(self):
        self.engine = None
        self.session = None

    def open_spider(self, spider):
        db_url = os.environ.get('DATABASE_URL')
        self.engine = create_engine(db_url)
        Base.metadata.create_all(self.engine)
        Session = sessionmaker(bind=self.engine)
        self.session = Session()

    def close_spider(self, spider):
        self.session.close()

    def process_item(self, item, spider):
        article = NewsArticle(
            title=item['title'],
            url=item['url'],
            content=item.get('content', ''),
            author=item.get('author', ''),
            published_date=item.get('published_date', ''),
            source=item['source'],
            scraped_at=item.get('scraped_at', datetime.datetime.utcnow())
        )
        
        try:
            self.session.add(article)
            self.session.commit()
        except Exception as e:
            self.session.rollback()
            spider.logger.error(f"Failed to save item to database: {e}")
        
        return item

class JsonWriterPipeline:
    def open_spider(self, spider):
        self.file = open('/data/items.json', 'w')
        self.file.write('[\n')
        self.first_item = True

    def close_spider(self, spider):
        self.file.write('\n]')
        self.file.close()

    def process_item(self, item, spider):
        line = json.dumps(dict(item))
        if self.first_item:
            self.first_item = False
        else:
            self.file.write(',\n')
        self.file.write(line)
        return item
