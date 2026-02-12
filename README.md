
# Medical GenAI (Med-RAG)

An advanced Retrieval-Augmented Generation (RAG) system for medical queries, featuring a Python backend, a Flutter mobile application, and a Next.js web interface.

## 🏗️ Architecture

The project consists of three main components:

1. **Backend (`medical-genai-rag`)**:
    - Python-based RAG pipeline using PyTorch, HuggingFace Transformers, and FAISS.
    - Exposes a FastAPI server for external clients.
    - Handles document ingestion, embedding, and LLM inference.

2. **Mobile App (`medical_genai_app`)**:
    - Flutter-based mobile client (Android/iOS).
    - Provides a chat interface and system monitoring dashboard.
    - Connects to the backend API.

3. **Web UI (`medical-genai-ui`)**:
    - Next.js web application.
    - Modern, responsive interface for interacting with the medical assistant.

---

## 🚀 Getting Started

### Prerequisites

- **Docker** and **Docker Compose** (recommended for full stack)
- **Python 3.10+** (for backend)
- **Flutter SDK** (for mobile)
- **Node.js 18+** (for web)

### 1. Backend Setup

```bash
cd medical-genai-rag
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt

# Start the server
python -m api.app
```

The API will be available at `http://localhost:8080`.

### 2. Mobile App Setup

```bash
cd medical_genai_app
flutter pub get
flutter run
```

### 3. Web UI Setup

```bash
cd medical-genai-ui
npm install
npm run dev
```

The web app will be running at `http://localhost:3000`.

---

## 🤝 Contribution Guidelines

We welcome contributions! Please follow these steps:

1. **Fork the repository**.
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`).
3. **Commit your changes** (`git commit -m 'Add some amazing feature'`).
4. **Push to the branch** (`git push origin feature/amazing-feature`).
5. **Open a Pull Request**.

### CI/CD

This repository uses GitHub Actions for Continuous Integration:

- **Backend**: runs linting (`flake8`) and tests (`pytest`) on changes to `medical-genai-rag/`.
- **Mobile**: runs analysis and tests (`flutter test`) on changes to `medical_genai_app/`.
- **Web**: runs linting and build checks on changes to `medical-genai-ui/`.

Ensure all checks pass before submitting your PR.

---

## ⚠️ Disclaimer

This system is for **educational and research purposes only**. It does NOT provide medical advice. Always consult a qualified healthcare professional.
