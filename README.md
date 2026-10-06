# GradeLens — Production Document Intelligence & Academic CGPA Platform

> An enterprise-grade, document-intelligence-powered academic evaluation system for students and institutions.

GradeLens automatically ingests student grade-sheet photos, scans, and PDFs, applies computer vision and OCR to identify headings, semesters, and examination types (Regular, Supplementary, Backlog, Revaluation), reconstructs subject tables, reconciles multi-attempt academic histories, and computes mathematically accurate SGPA and cumulative CGPA across configurable institutional policies.

---

## 🏛️ System Architecture Specification

The complete, production-grade architectural specification covering all 24 engineering criteria is documented in:
📄 **[docs/SYSTEM_ARCHITECTURE.md](docs/SYSTEM_ARCHITECTURE.md)**

### Key Highlights
- **Default Grading Scale:** `EX=10, A=9, B=8, C=7, D=6, P=5, M=4, F=0`
- **Multi-Attempt Modeling:** Distinct hierarchy (`Student` $\to$ `Semester` $\to$ `AcademicAttempt` $\to$ `GradeSheet` $\to$ `SubjectAttempt` $\to$ `EffectiveSubjectResult`)
- **Backlog Reconciliation:** Separates historical raw attempts from effective results; guarantees zero double-counting of credits.
- **Heading-First OCR:** Segments top 25–35% ROI for semester and exam type detection before table extraction.
- **Confidence Scoring:** Cell-level bounding boxes and confidence flags requiring human review below $70\%$ threshold.

