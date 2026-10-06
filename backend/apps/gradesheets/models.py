import uuid
from django.db import models
from apps.students.models import StudentProfile
from apps.semesters.models import AcademicAttempt

class GradeSheet(models.Model):
    DOC_TYPES = (
        ('GRADE_SHEET', 'Grade Sheet'),
        ('MARKS_MEMO', 'Marks Memo'),
        ('TRANSCRIPT', 'Transcript'),
        ('SUPPLEMENTARY_SHEET', 'Supplementary Grade Sheet'),
        ('BACKLOG_SHEET', 'Backlog Grade Sheet'),
        ('REVALUATION_RESULT', 'Revaluation Result'),
        ('UNKNOWN_DOCUMENT', 'Unknown Document'),
    )

    UPLOAD_STATUS = (
        ('UPLOADED', 'Uploaded'),
        ('PROCESSING', 'Processing'),
        ('REVIEW_REQUIRED', 'Review Required'),
        ('VERIFIED', 'Verified'),
        ('REJECTED', 'Rejected'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='gradesheets')
    academic_attempt = models.ForeignKey(AcademicAttempt, on_delete=models.SET_NULL, null=True, blank=True, related_name='gradesheets')
    original_filename = models.CharField(max_length=255)
    file = models.FileField(upload_to='gradesheets/%Y/%m/')
    file_hash = models.CharField(max_length=64, db_index=True)
    document_type = models.CharField(max_length=40, choices=DOC_TYPES, default='GRADE_SHEET')
    upload_status = models.CharField(max_length=30, choices=UPLOAD_STATUS, default='UPLOADED')
    is_duplicate = models.BooleanField(default=False)

    # Extracted Header Metadata
    raw_header_text = models.TextField(blank=True)
    detected_semester = models.PositiveSmallIntegerField(null=True, blank=True)
    semester_confidence = models.FloatField(default=0.0)
    detected_exam_type = models.CharField(max_length=50, default='REGULAR')
    exam_type_confidence = models.FloatField(default=0.0)
    extracted_student_name = models.CharField(max_length=255, blank=True)
    extracted_reg_no = models.CharField(max_length=100, blank=True)
    extracted_institution = models.CharField(max_length=255, blank=True)
    extracted_session = models.CharField(max_length=100, blank=True)
    student_match_verified = models.BooleanField(default=True)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.original_filename} (Sem {self.detected_semester or '?'})"

class OCRExtraction(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    gradesheet = models.OneToOneField(GradeSheet, on_delete=models.CASCADE, related_name='extraction')
    raw_text = models.TextField(blank=True)
    extracted_data = models.JSONField(default=dict)
    overall_confidence = models.FloatField(default=0.0)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Extraction for {self.gradesheet.original_filename}"

class OCRField(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    extraction = models.ForeignKey(OCRExtraction, on_delete=models.CASCADE, related_name='fields')
    field_name = models.CharField(max_length=100)
    raw_value = models.CharField(max_length=255)
    normalized_value = models.CharField(max_length=255)
    confidence = models.FloatField(default=1.0)
    bounding_box = models.JSONField(default=list)  # [x, y, w, h]
    needs_review = models.BooleanField(default=False)
    user_corrected = models.BooleanField(default=False)

    def __str__(self):
        return f"{self.field_name}: {self.normalized_value} ({self.confidence * 100:.1f}%)"
