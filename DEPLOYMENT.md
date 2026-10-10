# GradeNexus - Production Deployment Guide

GradeNexus is an intelligent, high-accuracy academic analytics and grade sheet processing system powered by a **Flutter frontend** and a **Django REST backend** with OCR/CV extraction pipelines.

---

## 🚀 Option 1: One-Click Docker Deployment (Recommended)

GradeNexus includes a production-grade `docker-compose.yml` with reverse proxying via Nginx:

### Prerequisites:
- Docker Desktop or Docker Engine installed and running.

### Launch:
```bash
# Clone the repository
git clone https://github.com/mora-sanjay/CGPA_Calculator.git
cd CGPA_Calculator

# Build and start all services in the background
docker compose up --build -d
```

### Services Started:
- **GradeNexus Web (Nginx)**: `http://localhost:80`
- **GradeNexus Backend (Django)**: `http://localhost:8000/api/`
- **PostgreSQL Database**: Port `5432`
- **Redis Cache & Celery Broker**: Port `6379`

### Stopping the Services:
```bash
docker compose down
```

---

## ⚡ Option 2: Instant Local Production Launch (Windows / Mac / Linux)

If Docker is not running, you can run the pre-compiled production release directly:

### On Windows:
Double-click `start_production.bat` or run in PowerShell:
```cmd
.\start_production.bat
```
This automatically:
1. Migrates the database.
2. Boots the Django REST backend at `http://localhost:8000`.
3. Serves the pre-compiled Flutter Web production build at `http://localhost:5000`.
4. Opens your default browser to GradeNexus.

### On Linux / macOS:
```bash
# Terminal 1: Backend
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py runserver 0.0.0.0:8000

# Terminal 2: Production Web
cd frontend/build/web
python3 -m http.server 5000
# Open http://localhost:5000 in your browser
```

---

## 📱 Mobile & Desktop Native Builds

### Android APK / App Bundle:
```bash
cd frontend
flutter build apk --release
# Output APK: frontend/build/app/outputs/flutter-apk/app-release.apk
```

### Windows Desktop Executable:
```bash
cd frontend
flutter build windows --release
# Output EXE: frontend/build/windows/x64/runner/Release/gradenexus.exe
```

---

## ☁️ Option 3: Cloud Deployment (Render / Railway / VPS)

### Backend (Render or Railway):
1. **Build Command**: `pip install -r requirements.txt && apt-get update && apt-get install -y tesseract-ocr tesseract-ocr-eng libgl1`
2. **Start Command**: `gunicorn gradelens.wsgi:application --bind 0.0.0.0:$PORT`
3. **Environment Variables**:
   - `DEBUG=0`
   - `DJANGO_SECRET_KEY=<your-secret-key>`
   - `DATABASE_URL=<postgres-connection-string>`

### Frontend (Vercel / Netlify / Cloudflare Pages):
1. Build folder: `frontend/build/web`
2. Redirects / SPA routing: rewrite `/*` to `/index.html`
3. Set backend API URL in environment or reverse proxy `/api/`.
