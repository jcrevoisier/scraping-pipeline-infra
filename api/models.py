from sqlalchemy import Column, Integer, String, Text, DateTime, create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
import datetime

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

# Database connection
db_url = os.environ.get('DATABASE_URL')
engine = create_engine(db_url)
Base.metadata.create_all(engine)
SessionLocal = sessionmaker(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
