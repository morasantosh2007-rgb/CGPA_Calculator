import uuid
from decimal import Decimal
from django.db import models
from apps.semesters.models import Semester
from apps.students.models import StudentProfile

class SemesterResult(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    semester = models.OneToOneField(Semester, on_delete=models.CASCADE, related_name='result')
    sgpa = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('0.00'))
    total_credits_registered = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('0.00'))
    total_credits_earned = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('0.00'))
    has_backlogs = models.BooleanField(default=False)
    calculated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"Sem {self.semester.semester_number} SGPA: {self.sgpa}"

class AcademicSummary(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.OneToOneField(StudentProfile, on_delete=models.CASCADE, related_name='academic_summary')
    cgpa = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('0.00'))
    total_credits_completed = models.DecimalField(max_digits=6, decimal_places=2, default=Decimal('0.00'))
    total_backlogs_count = models.PositiveIntegerField(default=0)
    cleared_backlogs_count = models.PositiveIntegerField(default=0)
    active_backlogs_count = models.PositiveIntegerField(default=0)
    highest_sgpa = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('0.00'))
    lowest_sgpa = models.DecimalField(max_digits=5, decimal_places=2, default=Decimal('0.00'))
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.student.user.email} CGPA: {self.cgpa} ({self.total_credits_completed} credits)"
