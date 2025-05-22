from fastapi import FastAPI, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from typing import List, Optional
from models import NewsArticle, get_db
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel
from datetime import datetime

app = FastAPI(title="News Scraper API")

# Setup Prometheus metrics
Instrumentator().instrument(app).expose(app)

class NewsArticleResponse(BaseModel):
    id: int
    title: str
    url: str
    content: Optional[str] = None
    author: Optional[str] = None
    published_date: Optional[str] = None
    source: str
    scraped_at: datetime

    class Config:
        orm_mode = True

@app.get("/")
def read_root():
    return {"message": "Welcome to the News Scraper API"}

@app.get("/articles", response_model=List[NewsArticleResponse])
def get_articles(
    skip: int = 0, 
    limit: int = 100,
    source: Optional[str] = None,
    db: Session = Depends(get_db)
):
    query = db.query(NewsArticle)
    
    if source:
        query = query.filter(NewsArticle.source == source)
    
    articles = query.order_by(NewsArticle.scraped_at.desc()).offset(skip).limit(limit).all()
    return articles

@app.get("/articles/{article_id}", response_model=NewsArticleResponse)
def get_article(article_id: int, db: Session = Depends(get_db)):
    article = db.query(NewsArticle).filter(NewsArticle.id == article_id).first()
    if article is None:
        raise HTTPException(status_code=404, detail="Article not found")
    return article

@app.get("/sources")
def get_sources(db: Session = Depends(get_db)):
    sources = db.query(NewsArticle.source).distinct().all()
    return {"sources": [source[0] for source in sources]}

@app.get("/stats")
def get_stats(db: Session = Depends(get_db)):
    total_articles = db.query(NewsArticle).count()
    sources = db.query(NewsArticle.source, db.func.count(NewsArticle.id)).group_by(NewsArticle.source).all()
    
    return {
        "total_articles": total_articles,
        "by_source": {source: count for source, count in sources}
    }
