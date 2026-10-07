import uuid
from django.db import models
from django.conf import settings
from apps.grading.models import GradingSystem, CalculationPolicy

class University(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=255)
    code = models.CharField(max_length=50, blank=True)
    country = models.CharField(max_length=100, default='India')

    def __str__(self):
        return self.name

class StudentProfile(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    user = models.OneToOneField(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='student_profile')
    full_name = models.CharField(max_length=255, blank=True)
    registration_number = models.CharField(max_length=100, blank=True, db_index=True)
    roll_number = models.CharField(max_length=100, blank=True, db_index=True)
    department = models.CharField(max_length=255, blank=True)
    academic_year = models.CharField(max_length=100, blank=True)
    institute_email = models.EmailField(blank=True)
    university_name = models.CharField(max_length=255, blank=True)
    university = models.ForeignKey(University, on_delete=models.SET_NULL, null=True, blank=True, related_name='students')
    grading_system = models.ForeignKey(GradingSystem, on_delete=models.SET_NULL, null=True, blank=True, related_name='students')
    calculation_policy = models.ForeignKey(CalculationPolicy, on_delete=models.SET_NULL, null=True, blank=True, related_name='students')
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return f"{self.user.email} ({self.registration_number or 'Unregistered'})"
