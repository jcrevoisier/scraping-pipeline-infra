#!/bin/bash

# Exit on error
set -e

# Configuration
PROJECT_ID="your-gcp-project-id"
REGION="us-central1"
CLUSTER_NAME="scraper-cluster"
MACHINE_TYPE="e2-standard-2"

# Ensure gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "gcloud could not be found. Please install Google Cloud SDK."
    exit 1
fi

# Ensure kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl could not be found. Installing..."
    gcloud components install kubectl
fi

# Ensure docker is installed
if ! command -v docker &> /dev/null; then
    echo "docker could not be found. Please install Docker."
    exit 1
fi

# Set GCP project
echo "Setting GCP project to $PROJECT_ID..."
gcloud config set project $PROJECT_ID

# Enable required APIs
echo "Enabling required GCP APIs..."
gcloud services enable container.googleapis.com \
    containerregistry.googleapis.com \
    cloudbuild.googleapis.com

# Create GKE cluster if it doesn't exist
if ! gcloud container clusters describe $CLUSTER_NAME --region $REGION &> /dev/null; then
    echo "Creating GKE cluster $CLUSTER_NAME..."
    gcloud container clusters create $CLUSTER_NAME \
        --region $REGION \
        --machine-type $MACHINE_TYPE \
        --num-nodes 2 \
        --enable-autoscaling \
        --min-nodes 1 \
        --max-nodes 3
else
    echo "GKE cluster $CLUSTER_NAME already exists."
fi

# Get credentials for kubectl
echo "Getting credentials for kubectl..."
gcloud container clusters get-credentials $CLUSTER_NAME --region $REGION

# Build and push Docker images
echo "Building and pushing Docker images..."
cd ..

# Build and push scraper image
docker build -t gcr.io/$PROJECT_ID/scraper:latest ./scrapers
docker push gcr.io/$PROJECT_ID/scraper:latest

# Build and push scheduler image
docker build -t gcr.io/$PROJECT_ID/scheduler:latest ./scheduler
docker push gcr.io/$PROJECT_ID/scheduler:latest

# Build and push API image
docker build -t gcr.io/$PROJECT_ID/api:latest ./api
docker push gcr.io/$PROJECT_ID/api:latest

# Create Kubernetes namespace if it doesn't exist
if ! kubectl get namespace scraper &> /dev/null; then
    echo "Creating Kubernetes namespace 'scraper'..."
    kubectl create namespace scraper
else
    echo "Kubernetes namespace 'scraper' already exists."
fi

# Create Kubernetes secrets for database credentials
echo "Creating Kubernetes secrets..."
kubectl create secret generic db-credentials \
    --namespace scraper \
    --from-literal=POSTGRES_USER=$(grep POSTGRES_USER .env | cut -d '=' -f2) \
    --from-literal=POSTGRES_PASSWORD=$(grep POSTGRES_PASSWORD .env | cut -d '=' -f2) \
    --from-literal=POSTGRES_DB=$(grep POSTGRES_DB .env | cut -d '=' -f2) \
    --dry-run=client -o yaml | kubectl apply -f -

# Create Kubernetes secrets for Grafana credentials
kubectl create secret generic grafana-credentials \
    --namespace scraper \
    --from-literal=GRAFANA_USER=$(grep GRAFANA_USER .env | cut -d '=' -f2) \
    --from-literal=GRAFANA_PASSWORD=$(grep GRAFANA_PASSWORD .env | cut -d '=' -f2) \
    --dry-run=client -o yaml | kubectl apply -f -

# Apply Kubernetes manifests
echo "Applying Kubernetes manifests..."
# Create a temporary directory for Kubernetes manifests
mkdir -p k8s_manifests

# Create persistent volume claims
cat > k8s_manifests/pvc.yaml << EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgres-data
  namespace: scraper
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 10Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: prometheus-data
  namespace: scraper
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: grafana-data
  namespace: scraper
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 2Gi
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: scraped-data
  namespace: scraper
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
EOF

# Create deployments
cat > k8s_manifests/deployments.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
  namespace: scraper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: db-credentials
              key: POSTGRES_DB
        ports:
        - containerPort: 5432
        volumeMounts:
        - name: postgres-data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: postgres-data
        persistentVolumeClaim:
          claimName: postgres-data
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: scraper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:7
        ports:
        - containerPort: 6379
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scraper
  namespace: scraper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scraper
  template:
    metadata:
      labels:
        app: scraper
    spec:
      containers:
      - name: scraper
        image: gcr.io/$PROJECT_ID/scraper:latest
        env:
        - name: DATABASE_URL
          value: postgresql://\$(POSTGRES_USER):\$(POSTGRES_PASSWORD)@postgres:5432/\$(POSTGRES_DB)
        envFrom:
        - secretRef:
            name: db-credentials
        volumeMounts:
        - name: scraped-data
          mountPath: /data
      volumes:
      - name: scraped-data
        persistentVolumeClaim:
          claimName: scraped-data
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: scheduler
  namespace: scraper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: scheduler
  template:
    metadata:
      labels:
        app: scheduler
    spec:
      containers:
      - name: scheduler
        image: gcr.io/$PROJECT_ID/scheduler:latest
        env:
        - name: REDIS_URL
          value: redis://redis:6379/0
        - name: DATABASE_URL
          value: postgresql://\$(POSTGRES_USER):\$(POSTGRES_PASSWORD)@postgres:5432/\$(POSTGRES_DB)
        envFrom:
        - secretRef:
            name: db-credentials
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api
  namespace: scraper
spec:
  replicas: 2
  selector:
    matchLabels:
      app: api
  template:
    metadata:
      labels:
        app: api
    spec:
      containers:
      - name: api
        image: gcr.io/$PROJECT_ID/api:latest
        ports:
        - containerPort: 8000
        env:
        - name: DATABASE_URL
          value: postgresql://\$(POSTGRES_USER):\$(POSTGRES_PASSWORD)@postgres:5432/\$(POSTGRES_DB)
        envFrom:
        - secretRef:
            name: db-credentials
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: scraper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: prometheus-config
          mountPath: /etc/prometheus/prometheus.yml
          subPath: prometheus.yml
        - name: prometheus-data
          mountPath: /prometheus
      volumes:
      - name: prometheus-config
        configMap:
          name: prometheus-config
      - name: prometheus-data
        persistentVolumeClaim:
          claimName: prometheus-data
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: scraper
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_USER
          valueFrom:
            secretKeyRef:
              name: grafana-credentials
              key: GRAFANA_USER
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-credentials
              key: GRAFANA_PASSWORD
        volumeMounts:
        - name: grafana-datasources
          mountPath: /etc/grafana/provisioning/datasources/datasources.yml
          subPath: datasources.yml
        - name: grafana-data
          mountPath: /var/lib/grafana
      volumes:
      - name: grafana-datasources
        configMap:
          name: grafana-datasources
      - name: grafana-data
        persistentVolumeClaim:
          claimName: grafana-data
EOF

# Create services
cat > k8s_manifests/services.yaml << EOF
apiVersion: v1
kind: Service
metadata:
  name: postgres
  namespace: scraper
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
    targetPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: scraper
spec:
  selector:
    app: redis
  ports:
  - port: 6379
    targetPort: 6379
---
apiVersion: v1
kind: Service
metadata:
  name: api
  namespace: scraper
spec:
  selector:
    app: api
  ports:
  - port: 80
    targetPort: 8000
  type: LoadBalancer
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: scraper
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
  type: ClusterIP
---
apiVersion: v1
kind: Service
metadata:
  name: grafana
  namespace: scraper
spec:
  selector:
    app: grafana
  ports:
  - port: 80
    targetPort: 3000
  type: LoadBalancer
EOF

# Create ConfigMaps
cat > k8s_manifests/configmaps.yaml << EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: scraper
data:
  prometheus.yml: |
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
    
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
    
      - job_name: 'api'
        static_configs:
          - targets: ['api:8000']
    
      - job_name: 'scraper'
        static_configs:
          - targets: ['scraper:9410']
    
      - job_name: 'redis'
        static_configs:
          - targets: ['redis:6379']
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: grafana-datasources
  namespace: scraper
data:
  datasources.yml: |
    apiVersion: 1
    
    datasources:
      - name: Prometheus
        type: prometheus
        access: proxy
        url: http://prometheus:9090
        isDefault: true
EOF

# Apply Kubernetes manifests
kubectl apply -f k8s_manifests/

# Wait for deployments to be ready
echo "Waiting for deployments to be ready..."
kubectl wait --namespace scraper --for=condition=available --timeout=300s deployment/postgres
kubectl wait --namespace scraper --for=condition=available --timeout=300s deployment/redis
kubectl wait --namespace scraper --for=condition=available --timeout=300s deployment/scraper
kubectl wait --namespace scraper --for=condition=available --timeout=300s deployment/scheduler
kubectl wait --namespace scraper --for=condition=available --timeout=300s deployment/api
kubectl wait --namespace scraper --for=condition=available --timeout=300s deployment/prometheus
kubectl wait --namespace scraper --for=condition=available --timeout=300s deployment/grafana

# Get external IP addresses
API_IP=$(kubectl get service api --namespace scraper -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
GRAFANA_IP=$(kubectl get service grafana --namespace scraper -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Deployment completed successfully!"
echo "API is accessible at: http://$API_IP"
echo "Grafana dashboard is accessible at: http://$GRAFANA_IP"
echo "Login to Grafana with the credentials from your .env file"
EOF

# Make the deployment script executable
chmod +x k8s_manifests/deployments.yaml

# Clean up temporary directory
echo "Applying Kubernetes manifests..."
kubectl apply -f k8s_manifests/pvc.yaml
kubectl apply -f k8s_manifests/configmaps.yaml
kubectl apply -f k8s_manifests/deployments.yaml
kubectl apply -f k8s_manifests/services.yaml

# Clean up
rm -rf k8s_manifests

echo "Deployment to GCP completed successfully!"
