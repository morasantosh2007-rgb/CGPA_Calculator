import uuid
from django.db import models
from apps.students.models import StudentProfile

class Semester(models.Model):
    STATUS_CHOICES = (
        ('IN_PROGRESS', 'In Progress'),
        ('COMPLETED', 'Completed'),
        ('BACKLOGS_PENDING', 'Backlogs Pending'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='semesters')
    semester_number = models.PositiveSmallIntegerField(db_index=True)
    academic_year = models.CharField(max_length=50, blank=True)
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='COMPLETED')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        unique_together = ('student', 'semester_number')
        ordering = ['semester_number']

    def __str__(self):
        return f"Semester {self.semester_number} - {self.student.user.email}"

class AcademicAttempt(models.Model):
    EXAM_TYPE_CHOICES = (
        ('REGULAR', 'Regular'),
        ('SUPPLEMENTARY', 'Supplementary'),
        ('BACKLOG', 'Backlog'),
        ('REVALUATION', 'Revaluation'),
        ('IMPROVEMENT', 'Improvement'),
        ('REPEAT', 'Repeat'),
        ('UNKNOWN', 'Unknown'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    semester = models.ForeignKey(Semester, on_delete=models.CASCADE, related_name='attempts')
    attempt_number = models.PositiveSmallIntegerField(default=1)
    exam_type = models.CharField(max_length=30, choices=EXAM_TYPE_CHOICES, default='REGULAR')
    raw_exam_type = models.CharField(max_length=150, blank=True)
    academic_session = models.CharField(max_length=100, blank=True)
    exam_date = models.CharField(max_length=50, blank=True)
    is_verified = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        unique_together = ('semester', 'attempt_number')
        ordering = ['attempt_number']

    def __str__(self):
        return f"Sem {self.semester.semester_number} Attempt {self.attempt_number} ({self.exam_type})"
