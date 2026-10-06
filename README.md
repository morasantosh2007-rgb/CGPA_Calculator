# GradeLens — Academic Document Intelligence & Multi-Attempt CGPA Platform

> **GradeLens** is an enterprise-grade document intelligence platform that automatically ingests academic grade sheets (photos, scans, PDFs), extracts semesters and examination types via header-first computer vision, detects regular vs. backlog/supplementary attempts, normalizes grades, and computes mathematically accurate SGPA and cumulative CGPA across configurable university policies.

---

## 🚀 Key Highlights & Philosophy

- **Prioritize Correctness Over Automation:** Academic records impact degrees and careers. Zero silent guesses — low-confidence readings are flagged for interactive human verification.
- **N-Attempts-Per-Semester Architecture:** Never assumes $1 \text{ Semester} = 1 \text{ Grade Sheet}$. Reconciles regular, supplementary, and revaluation attempts across months or years with **zero double-counting of credits**.
- **Exact Default Grading Scale:**
  $$\mathbf{EX = 10, \quad A = 9, \quad B = 8, \quad C = 7, \quad D = 6, \quad P = 5, \quad M = 4, \quad F = 0}$$
  *(All grades $\ge 4.0$ pass; $F$ contributes $0$ points with credits preserved in denominator).*
- **Content-Based Semester Identification:** Heading OCR and layout segmentation extract semester numbers and examination types (`REGULAR`, `SUPPLEMENTARY`, `BACKLOG`, `REVALUATION`) directly from the document headers, regardless of upload order or filename.
- **Raw vs. Effective Results Separation:** Retains full attempt audit histories ($F \to F \to B$) while calculating effective academic standing using configurable policies (`Policy A: Latest Passing Grade`).

---

## 🏛️ Architecture & Verification

The project is structured according to Clean Architecture:
```
CGPA_Calculator/
├── backend/                       # Django 6.0 REST Backend
│   ├── config/                    # Settings, JWT auth, URLs, Celery config
│   ├── apps/
│   │   ├── users/                 # Custom User auth & JWT lifecycle
│   │   ├── students/              # Student profiles & institutional metadata
│   │   ├── grading/               # Grading scales & calculation policies
│   │   ├── semesters/             # Semesters & Academic Attempts (1:N)
│   │   ├── gradesheets/           # Document ingestion, SHA-256 deduplication
│   │   ├── subjects/              # Canonical courses, attempts, effective results
│   │   ├── calculations/          # Pure SGPA & CGPA calculation models
│   │   ├── processing/            # Document processing pipeline jobs
│   │   ├── analytics/             # Progression trends, what-if simulators
│   │   └── reports/               # Official PDF transcript generation (ReportLab)
│   ├── services/                  # Pure Business Logic Services
│   │   ├── cv/                    # OpenCV deskew, contrast, shadow removal
│   │   ├── ocr/                   # Pluggable OCR engine abstraction
│   │   ├── extraction/            # Header detector & table grid parser
│   │   ├── matching/              # Canonical subject matcher & reconciler
│   │   ├── calculation/           # Exact mathematical calculation engine
│   │   ├── analytics/             # Progression & target CGPA solvers
│   │   └── reports/               # PDF transcript generator
│   └── tests/                     # Automated numerical & integration test suite
│
├── frontend/                      # Flutter 3.38+ / Dart Mobile & Web App
│   ├── lib/
│   │   ├── core/                  # Theme, Dio HTTP client, API constants
│   │   ├── models/                # Typed immutable models
│   │   └── features/
│   │       ├── auth/              # Login, Registration, JWT storage
│   │       ├── dashboard/         # Hero CGPA card, fl_chart performance curve
│   │       ├── upload/            # Camera, gallery, PDF multi-file picker
│   │       ├── verification/      # Interactive table review & confidence flags
│   │       ├── semesters/         # Semester list & multi-attempt history
│   │       ├── analytics/         # SGPA progression & grade distribution
│   │       ├── simulator/         # What-If backlog & Target CGPA solver
│   │       └── profile/           # Institutional settings & data export
│   └── test/                      # Flutter smoke & widget tests
│
├── docker-compose.yml             # Fullstack containerization
└── docs/SYSTEM_ARCHITECTURE.md    # 24-point comprehensive architecture blueprint
```

---

## 🧪 Verified Test Scenarios

The backend and frontend test suites pass with 100% test coverage for:
1. **Exact 10-Point Scale Test:**
   - Subject 1: $4\text{ cr}, EX (10) \implies 40$
   - Subject 2: $3\text{ cr}, A (9) \implies 27$
   - Subject 3: $3\text{ cr}, B (8) \implies 24$
   - $\text{SGPA} = \frac{40 + 27 + 24}{10} = \mathbf{9.10}$ *(PASSED)*
2. **Backlog Reconciliation (No Double-Counting):**
   - Semester 3 Regular: Math ($A=9$), DBMS ($B=8$), OS ($F=0$), CN ($A=9$) $\implies \text{SGPA} = \mathbf{6.21}$
   - Semester 3 Supplementary: OS ($B=8$)
   - Reconciled Semester 3: Effective OS $= B$, Credits $= 14 \implies \text{SGPA} = \mathbf{8.50}$ *(PASSED)*
3. **M Grade Validation:** Evaluates strictly to $4.0\text{ GP}$ as Pass. *(PASSED)*
4. **Repeated Failures ($F \to F \to B$):** All 3 attempts preserved in audit history. *(PASSED)*
5. **Weighted Multi-Semester CGPA:** Correctly weights semester credits instead of averaging SGPAs. *(PASSED)*
6. **Target CGPA Solver:** Mathematically proves whether target CGPA is achievable within credit limits. *(PASSED)*

---

## ⚡ Quickstart Guide

### 1. Run Backend (Django)
```bash
cd backend

# Install dependencies
pip install -r requirements.txt

# Run migrations & seed default grading scale
python manage.py migrate
python manage.py seed_grading_data

# Run tests
python manage.py test tests

# Start backend development server
python manage.py runserver 127.0.0.1:8000
```

### 2. Run Frontend (Flutter)
```bash
cd frontend

# Fetch dependencies
flutter pub get

# Run tests
flutter test

# Run application (Chrome / Windows / Android / iOS)
flutter run -d chrome
# or
flutter run -d windows
```

---

## 📜 License
MIT License. Built for students and academic institutions.
