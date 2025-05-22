from celery import Celery
import os

app = Celery('scraper_tasks',
             broker=os.environ.get('REDIS_URL', 'redis://localhost:6379/0'),
             include=['tasks'])

app.conf.beat_schedule = {
    'scrape-hackernews-every-hour': {
        'task': 'tasks.run_hackernews_spider',
        'schedule': 3600.0,  # Every hour
    },
    'scrape-bbcnews-every-2-hours': {
        'task': 'tasks.run_bbcnews_spider',
        'schedule': 7200.0,  # Every 2 hours
    },
    'cleanup-old-data-weekly': {
        'task': 'tasks.cleanup_old_data',
        'schedule': 604800.0,  # Every week
    },
}

app.conf.timezone = 'UTC'

if __name__ == '__main__':
    app.start()
