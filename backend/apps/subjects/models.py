import uuid
from decimal import Decimal
from django.db import models
from apps.students.models import StudentProfile
from apps.semesters.models import Semester, AcademicAttempt
from apps.gradesheets.models import GradeSheet

class Subject(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='subjects')
    subject_code = models.CharField(max_length=50, blank=True)
    normalized_code = models.CharField(max_length=50, db_index=True)
    subject_name = models.CharField(max_length=255)
    default_credits = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal('3.00'))
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['normalized_code', 'subject_name']

    def __str__(self):
        return f"{self.subject_code or 'NO_CODE'} - {self.subject_name}"

class SubjectAttempt(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name='attempts')
    academic_attempt = models.ForeignKey(AcademicAttempt, on_delete=models.CASCADE, related_name='subject_attempts')
    source_gradesheet = models.ForeignKey(GradeSheet, on_delete=models.SET_NULL, null=True, blank=True, related_name='subject_attempts')
    
    raw_grade = models.CharField(max_length=10)
    normalized_grade = models.CharField(max_length=10, db_index=True)
    grade_point = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal('0.00'))
    credits = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal('3.00'))
    is_pass = models.BooleanField(default=True)
    confidence = models.FloatField(default=1.0)
    user_corrected = models.BooleanField(default=False)
    original_value = models.CharField(max_length=50, blank=True)
    
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['created_at']

    def __str__(self):
        return f"{self.subject.subject_name} Attempt ({self.normalized_grade}, {self.grade_point} GP)"

class EffectiveSubjectResult(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE, related_name='effective_results')
    subject = models.ForeignKey(Subject, on_delete=models.CASCADE, related_name='effective_results')
    selected_attempt = models.ForeignKey(SubjectAttempt, on_delete=models.CASCADE, related_name='selected_for_effective')
    
    effective_grade = models.CharField(max_length=10)
    effective_grade_point = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal('0.00'))
    effective_credits = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal('3.00'))
    is_pass = models.BooleanField(default=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('semester', 'subject')
        ordering = ['subject__subject_name']

    def __str__(self):
        return f"Effective: {self.subject.subject_name} -> {self.effective_grade} ({self.effective_grade_point})"
