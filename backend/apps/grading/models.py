import uuid
from decimal import Decimal
from django.db import models

class GradingSystem(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    name = models.CharField(max_length=100)
    code = models.CharField(max_length=50, unique=True, default='DEFAULT_EX_F')
    description = models.TextField(blank=True)
    is_default = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name

class GradeRule(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    grading_system = models.ForeignKey(GradingSystem, related_name='rules', on_delete=models.CASCADE)
    grade = models.CharField(max_length=10, db_index=True)
    grade_point = models.DecimalField(max_digits=4, decimal_places=2, default=Decimal('0.00'))
    is_pass = models.BooleanField(default=True)
    counts_for_sgpa = models.BooleanField(default=True)
    counts_for_cgpa = models.BooleanField(default=True)
    order = models.PositiveIntegerField(default=0)

    class Meta:
        unique_together = ('grading_system', 'grade')
        ordering = ['order', '-grade_point']

    def __str__(self):
        return f"{self.grade} ({self.grade_point} GP, Pass={self.is_pass})"

class CalculationPolicy(models.Model):
    POLICY_CHOICES = (
        ('POLICY_A_LATEST_PASS', 'Policy A: Latest passing grade replaces failed attempt in SGPA & CGPA'),
        ('POLICY_B_FROZEN_SGPA', 'Policy B: Original SGPA frozen; CGPA updated with latest pass'),
        ('POLICY_C_HIGHEST_GRADE', 'Policy C: Highest grade achieved among all attempts'),
        ('POLICY_D_INSTITUTIONAL', 'Policy D: Custom institutional policy'),
    )

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    code = models.CharField(max_length=50, choices=POLICY_CHOICES, unique=True)
    name = models.CharField(max_length=150)
    description = models.TextField()
    is_default = models.BooleanField(default=False)

    def __str__(self):
        return self.name
