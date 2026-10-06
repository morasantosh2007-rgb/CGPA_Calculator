import uuid
from django.db import models
from apps.students.models import StudentProfile
from apps.gradesheets.models import GradeSheet

class ProcessingJob(models.Model):
    STATUS_CHOICES = (
        ('QUEUED', 'Queued'),
        ('PROCESSING', 'Processing'),
        ('REVIEW_REQUIRED', 'Review Required'),
        ('COMPLETED', 'Completed'),
        ('FAILED', 'Failed'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    student = models.ForeignKey(StudentProfile, on_delete=models.CASCADE, related_name='processing_jobs')
    gradesheet = models.ForeignKey(GradeSheet, on_delete=models.CASCADE, related_name='processing_jobs')
    status = models.CharField(max_length=30, choices=STATUS_CHOICES, default='QUEUED')
    stage = models.CharField(max_length=100, default='INIT')
    message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self):
        return f"Job {self.id} ({self.status}) - {self.stage}"
