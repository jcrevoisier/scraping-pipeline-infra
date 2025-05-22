import os
import subprocess
import datetime
from celery_app import app
from sqlalchemy import create_engine, text

@app.task
def run_hackernews_spider():
    """Task to run the Hacker News spider"""
    subprocess.run([
        'scrapy', 'crawl', 'hackernews',
        '-s', 'LOG_FILE=/app/logs/hackernews_$(date +%Y%m%d_%H%M%S).log'
    ], cwd='/app')
    return 'HackerNews spider completed'

@app.task
def run_bbcnews_spider():
    """Task to run the BBC News spider"""
    subprocess.run([
        'scrapy', 'crawl', 'bbcnews',
        '-s', 'LOG_FILE=/app/logs/bbcnews_$(date +%Y%m%d_%H%M%S).log'
    ], cwd='/app')
    return 'BBC News spider completed'

@app.task
def cleanup_old_data():
    """Task to clean up data older than 30 days"""
    db_url = os.environ.get('DATABASE_URL')
    engine = create_engine(db_url)
    
    thirty_days_ago = datetime.datetime.utcnow() - datetime.timedelta(days=30)
    
    with engine.connect() as connection:
        result = connection.execute(
            text("DELETE FROM news_articles WHERE scraped_at < :cutoff_date"),
            {"cutoff_date": thirty_days_ago}
        )
        connection.commit()
    
    return f'Cleaned up {result.rowcount} old records'
