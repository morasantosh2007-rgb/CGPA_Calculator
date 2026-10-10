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

## ☁️ Option 3: Cloud Deployment on Render (Step-by-Step)

GradeNexus backend is fully configured for Render with automated Docker builds, OpenCV/Tesseract system libraries, and Gunicorn production server.

### Deploying the Backend on Render:
1. Log in to [Render.com](https://render.com) and click **New +** $\to$ **Web Service**.
2. Connect your GitHub repository:
   `https://github.com/morasantosh2007-rgb/CGPA_Calculator`
3. Configure the service:
   - **Name**: `gradenexus-backend` (or your preferred name)
   - **Region**: Any (e.g. Oregon or Singapore)
   - **Branch**: `main`
   - **Root Directory**: *(Leave blank - uses repository root)*
   - **Runtime**: **Docker**
   - **Dockerfile Path**: *(Leave blank or `./Dockerfile` - Render picks up the root `Dockerfile` automatically)*
   - **Instance Type**: **Free**
4. Under **Advanced** / **Environment Variables**, add:
   - `PYTHONUNBUFFERED`: `1`
   - `DEBUG`: `True`
   - `PORT`: `10000` (Render defaults to this)
   - `DJANGO_SECRET_KEY`: *(Generate or enter any random string)*
5. **Health Check Path**: `/health/`
6. Click **Deploy Web Service**.
   Render will build the Docker container and start Gunicorn automatically!
   Your live backend URL will be: `https://<your-service-name>.onrender.com`

---

## 🌐 Connecting Frontend to Render Backend

Once your backend is live on Render:

### Web Deployment (Vercel / Netlify / GitHub Pages):
Build the web release pointing directly to your Render backend:
```bash
cd frontend
flutter build web --release --dart-define=API_BASE_URL=https://<your-service-name>.onrender.com/api
```
Deploy the generated `frontend/build/web/` folder to Vercel, Netlify, or Firebase Hosting.

### Mobile APK Build:
```bash
cd frontend
flutter build apk --release --dart-define=API_BASE_URL=https://<your-service-name>.onrender.com/api
```
The APK installed on Android devices will communicate directly with your Render cloud backend!

