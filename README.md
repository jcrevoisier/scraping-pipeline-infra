# Web Scraping Pipeline Infrastructure

A production-ready web scraping infrastructure with Docker, featuring multiple scrapers, task scheduling, data storage, and monitoring.

## Features

- **Multiple Scrapers**: Scrapy-based spiders for Hacker News and BBC News
- **Task Scheduling**: Celery with Redis for periodic scraping tasks
- **Data Storage**: PostgreSQL for structured data and JSON file backups
- **API**: FastAPI-based REST API to access and query scraped data
- **Monitoring**: Prometheus and Grafana for metrics collection and visualization
- **Containerization**: Docker and Docker Compose for easy deployment
- **Cloud Deployment**: Scripts for deploying to Google Cloud Platform

## Architecture

```
                                  ┌─────────────┐
                                  │   Grafana   │
                                  └──────┬──────┘
                                         │
┌─────────────┐    ┌─────────────┐    ┌──┴───────────┐
│   Scrapers   │───▶│  PostgreSQL  │◀───│  Prometheus  │
└──────┬──────┘    └──────┬───────┘    └──────────────┘
       │                  │
       │                  │
┌──────┴──────┐    ┌──────┴───────┐
│  Scheduler  │◀───▶│     API      │
└─────────────┘    └──────────────┘
```

## Technology Stack

- **Scrapy**: Web scraping framework
- **Celery**: Distributed task queue
- **Redis**: Message broker
- **PostgreSQL**: Data storage
- **FastAPI**: API framework
- **Prometheus**: Metrics collection
- **Grafana**: Metrics visualization
- **Docker**: Containerization
- **Google Cloud Platform**: Cloud deployment

## Prerequisites

- Docker and Docker Compose
- Google Cloud SDK (for cloud deployment)

## Getting Started

### Local Development

1. Clone the repository:
   ```bash
   git clone https://github.com/jcrevoisier/scraping-pipeline-infra.git
   cd scraping-pipeline-infra
   ```

2. Create a `.env` file with your configuration:
   ```
   POSTGRES_USER=scraper
   POSTGRES_PASSWORD=scraper_password
   POSTGRES_DB=scraper_db
   GRAFANA_USER=admin
   GRAFANA_PASSWORD=admin_password
   ```

3. Start the services:
   ```bash
   docker-compose up -d
   ```

4. Access the services:
   - API: http://localhost:8000
   - Grafana: http://localhost:3000 (login with GRAFANA_USER/GRAFANA_PASSWORD)
   - Prometheus: http://localhost:9090

### Cloud Deployment

To deploy to Google Cloud Platform:

1. Update the `PROJECT_ID` in `deploy/gcp_deploy.sh`
2. Run the deployment script:
   ```bash
   cd deploy
   ./gcp_deploy.sh
   ```

## API Endpoints

- `GET /articles`: List all scraped articles
- `GET /articles/{id}`: Get a specific article
- `GET /sources`: List all news sources
- `GET /stats`: Get scraping statistics

## Scheduled Tasks

- Hacker News: Scraped hourly
- BBC News: Scraped every 2 hours
- Data cleanup: Weekly (removes articles older than 30 days)

## Project Structure

```
scraping-pipeline-infra/
├── docker-compose.yml      # Docker Compose configuration
├── .env                    # Environment variables
├── scrapers/               # Scrapy spiders
├── scheduler/              # Celery task scheduler
├── api/                    # FastAPI application
├── monitoring/             # Prometheus and Grafana configs
└── deploy/                 # Deployment scripts
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.