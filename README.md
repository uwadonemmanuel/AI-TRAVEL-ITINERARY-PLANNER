# AI Travel Itinerary Planner

An intelligent travel itinerary planning application powered by LangChain and Groq's LLM, built with Streamlit and deployed on Kubernetes with comprehensive logging using the ELK-F stack.

## 🎯 Overview

The AI Travel Itinerary Planner is a web application that generates personalized day trip itineraries based on user-specified cities and interests. It leverages advanced language models to create detailed, context-aware travel plans.

## ✨ Features

- **AI-Powered Itinerary Generation**: Uses Groq's Llama 3.3 70B model to create personalized travel plans
- **Interactive Web Interface**: Built with Streamlit for an intuitive user experience
- **Kubernetes Deployment**: Fully containerized and deployable on Kubernetes
- **Comprehensive Logging**: Integrated ELK-F (Elasticsearch, Logstash, Kibana with FileBeat) stack for log aggregation and monitoring
- **Error Handling**: Robust error handling with custom exceptions and logging
- **Modular Architecture**: Clean, maintainable code structure with separation of concerns

## 🏗️ Architecture

```
┌─────────────────┐
│   Streamlit UI  │
└────────┬────────┘
         │
┌────────▼────────┐
│  TravelPlanner  │
└────────┬────────┘
         │
┌────────▼────────┐
│ Itinerary Chain │
└────────┬────────┘
         │
┌────────▼────────┐
│   ChatGroq LLM  │
└─────────────────┘
```

### Components

- **Frontend**: Streamlit web interface (`app.py`)
- **Core Logic**: `TravelPlanner` class (`src/core/planner.py`)
- **LLM Chain**: LangChain integration with Groq (`src/chains/itinerary_chain.py`)
- **Configuration**: Environment-based configuration (`src/config/config.py`)
- **Logging**: Custom logging utilities (`src/utils/logger.py`)
- **Exception Handling**: Custom exception classes (`src/utils/custom_exception.py`)

## 📋 Prerequisites

- Python 3.12+
- Docker (for containerization)
- Kubernetes cluster (Minikube or cloud-based)
- Groq API key ([Get one here](https://console.groq.com/))
- kubectl (Kubernetes CLI)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone <repository-url>
cd AI-TRAVEL-ITINEARY-PLANNER
```

### 2. Create Virtual Environment

```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 3. Install Dependencies

```bash
pip install -r requirements.txt
```

### 4. Configure Environment Variables

Create a `.env` file in the root directory:

```bash
GROQ_API_KEY=your_groq_api_key_here
```

### 5. Run Locally

```bash
streamlit run app.py
```

The application will be available at `http://localhost:8501`

## 📦 Installation Details

### Dependencies

The project requires the following Python packages:

- `langchain` - LLM framework
- `langchain_core` - Core LangChain functionality
- `langchain_groq` - Groq integration for LangChain
- `langchain_community` - Community extensions
- `python-dotenv` - Environment variable management
- `streamlit` - Web framework



## 🐳 Docker Deployment

### Build Docker Image

```bash
docker build -t streamlit-app:latest .
```

### Run Container

```bash
docker run -p 8501:8501 \
  -e GROQ_API_KEY=your_api_key \
  streamlit-app:latest
```

## ☸️ Kubernetes Deployment

### Prerequisites

- Minikube or Kubernetes cluster running
- kubectl configured
- Docker installed

### Step 1: Point Docker to Minikube

```bash
eval $(minikube docker-env)
```

### Step 2: Build Docker Image

```bash
docker build -t streamlit-app:latest .
```

### Step 3: Create Kubernetes Secret

```bash
kubectl create secret generic llmops-secrets \
  --from-literal=GROQ_API_KEY=your_groq_api_key_here
```

### Step 4: Deploy Application

```bash
kubectl apply -f k8s-deployment.yaml
```

### Step 5: Check Deployment Status

```bash
kubectl get pods
kubectl get svc
```

### Step 6: Access Application

```bash
kubectl port-forward svc/streamlit-service 8501:80 --address 0.0.0.0
```

Access the application at `http://localhost:8501`

## 📊 ELK Stack Setup (Logging & Monitoring)

The project includes a complete ELK stack setup for centralized logging and monitoring.

### Step 1: Create Logging Namespace

```bash
kubectl create namespace logging
```

### Step 2: Deploy Elasticsearch

```bash
kubectl apply -f elasticsearch.yaml
kubectl get pods -n logging
kubectl get pvc -n logging
```

**Note**: If you encounter cgroup v2 errors, see the troubleshooting section below.

### Step 3: Deploy Kibana

```bash
kubectl apply -f kibana.yaml
kubectl get pods -n logging
```

Access Kibana:
```bash
kubectl port-forward -n logging svc/kibana 5601:5601 --address 0.0.0.0
```

Open `http://localhost:5601` in your browser.

### Step 4: Deploy Logstash

```bash
kubectl apply -f logstash.yaml
kubectl get pods -n logging
```

### Step 5: Deploy Filebeat

```bash
kubectl apply -f filebeat.yaml
kubectl get all -n logging
```

### Step 6: Configure Kibana Index Patterns

1. Open Kibana at `http://localhost:5601`
2. Click **"Explore on my own"**
3. Navigate to **Stack Management → Index Patterns**
4. Create index pattern: `filebeat-*`
5. Select timestamp field: `@timestamp`
6. Click **Create Index Pattern**

### Step 7: Explore Logs

1. Go to **Analytics → Discover** in Kibana
2. View logs from all Kubernetes pods
3. Filter by `kubernetes.container.name` to see specific pod logs

## 🔧 Configuration

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `GROQ_API_KEY` | Your Groq API key | Yes |

### Application Configuration

- **Model**: Llama 3.3 70B Versatile
- **Temperature**: 0.3 (for consistent, focused responses)
- **LLM Provider**: Groq

### Kubernetes Resources

- **Memory Limit**: 2Gi
- **Memory Request**: 1Gi
- **CPU Limit**: 1 core
- **CPU Request**: 500m

## 📁 Project Structure

```
AI-TRAVEL-ITINEARY-PLANNER/
├── app.py                      # Streamlit main application
├── Dockerfile                  # Docker container definition
├── requirements.txt            # Python dependencies
├── setup.py                    # Package setup configuration
├── k8s-deployment.yaml        # Kubernetes deployment manifest
├── elasticsearch.yaml          # Elasticsearch deployment
├── kibana.yaml                 # Kibana deployment
├── logstash.yaml               # Logstash deployment
├── filebeat.yaml               # Filebeat deployment
├── src/
│   ├── core/
│   │   └── planner.py         # TravelPlanner core logic
│   ├── chains/
│   │   └── itinerary_chain.py # LangChain itinerary generation
│   ├── config/
│   │   └── config.py          # Configuration management
│   └── utils/
│       ├── logger.py          # Logging utilities
│       └── custom_exception.py # Custom exception classes
└── logs/                       # Application logs
```

## 🐛 Troubleshooting

### Elasticsearch Cgroup v2 Error

**Error:**
```
java.lang.NullPointerException: Cannot invoke "jdk.internal.platform.CgroupInfo.getMountPoint()"
```

**Solution:**
The current configuration uses Elasticsearch 8.11.0 which has improved cgroup v2 support. If issues persist:

1. Check pod logs:
   ```bash
   kubectl logs -n logging <pod-name> --tail=50
   ```

2. Verify security context and JVM options in `elasticsearch.yaml`

3. Check persistent volume claims:
   ```bash
   kubectl get pvc -n logging
   ```

### ModuleNotFoundError: No module named 'google'

**Solution:**
```bash
pip install protobuf
```

### Streamlit Import Errors

**Solution:**
Ensure all dependencies are installed:
```bash
pip install -r requirements.txt
```

### Connection Errors to Groq API

**Error:**
```
groq.APIConnectionError: Connection error
```

**Solutions:**
1. Verify `GROQ_API_KEY` is set correctly
2. Check network connectivity
3. Ensure the API key is valid and has sufficient quota

### Pod Stuck in Pending State

**Solution:**
```bash
kubectl describe pod <pod-name>
# Check for storage or resource issues
kubectl get pvc
```

### Application Not Accessible

**Solution:**
1. Check service is running:
   ```bash
   kubectl get svc
   ```

2. Verify port forwarding:
   ```bash
   kubectl port-forward svc/streamlit-service 8501:80
   ```

3. Check pod logs:
   ```bash
   kubectl logs <pod-name>
   ```

## 🧪 Development

### Running Tests

```bash
# Activate virtual environment
source venv/bin/activate

# Run the application
streamlit run app.py
```

### Code Structure

- **Core Logic**: `src/core/planner.py` - Main business logic
- **LLM Integration**: `src/chains/itinerary_chain.py` - LangChain chain setup
- **Configuration**: `src/config/config.py` - Environment configuration
- **Utilities**: `src/utils/` - Logging and exception handling

### Adding New Features

1. Create feature branch
2. Implement changes
3. Update tests
4. Submit pull request

## 📝 Usage

1. **Start the application**:
   ```bash
   streamlit run app.py
   ```

2. **Enter city name**: Type the destination city

3. **Enter interests**: Provide comma-separated interests (e.g., "museums, food, parks")

4. **Generate itinerary**: Click "Generate itinerary" button

5. **View results**: The AI-generated itinerary will be displayed

## 🔒 Security Considerations

- **API Keys**: Never commit API keys to version control
- **Secrets Management**: Use Kubernetes secrets for production
- **Environment Variables**: Store sensitive data in `.env` file (not tracked by git)
- **Network Security**: Use proper network policies in Kubernetes

## 📚 Additional Resources

- [LangChain Documentation](https://python.langchain.com/)
- [Groq API Documentation](https://console.groq.com/docs)
- [Streamlit Documentation](https://docs.streamlit.io/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ELK Stack Documentation](https://www.elastic.co/guide/)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 👥 Authors

- **Sudhanshu** - Initial work

## 🙏 Acknowledgments

- Groq for providing the LLM API
- LangChain team for the excellent framework
- Streamlit for the web framework
- Elastic for the ELK stack

## 📞 Support

For issues and questions:
1. Check the troubleshooting section
2. Review the full documentation in `FULL DOCUMENTATION.md`
3. Open an issue on GitHub

---

**Last Updated**: 2025-11-23  
**Version**: 0.1
