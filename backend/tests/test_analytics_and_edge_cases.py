from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from apps.students.models import StudentProfile
from apps.grading.models import GradingSystem, GradeRule
from apps.semesters.models import Semester, AcademicAttempt
from apps.subjects.models import Subject, SubjectAttempt
from services.calculation.engine import CalculationEngine
from services.analytics.service import AnalyticsService

User = get_user_model()

class AnalyticsAndEdgeCasesTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="test@gradelens.com", password="password123")
        self.grading_system = GradingSystem.objects.create(name="Standard", code="STD", is_default=True)
        rules = [
            ('EX', Decimal('10.00'), True),
            ('A',  Decimal('9.00'),  True),
            ('B',  Decimal('8.00'),  True),
            ('C',  Decimal('7.00'),  True),
            ('D',  Decimal('6.00'),  True),
            ('P',  Decimal('5.00'),  True),
            ('M',  Decimal('4.00'),  True),
            ('F',  Decimal('0.00'),  False),
        ]
        for grade, gp, is_pass in rules:
            GradeRule.objects.create(grading_system=self.grading_system, grade=grade, grade_point=gp, is_pass=is_pass)

        self.student = StudentProfile.objects.create(
            user=self.user,
            full_name="Alex Rivera",
            registration_number="REG999",
            grading_system=self.grading_system
        )

    def test_zero_credit_course_does_not_affect_sgpa(self):
        """Zero credit courses (e.g. Audit / Environmental Studies) must not distort SGPA."""
        sem = Semester.objects.create(student=self.student, semester_number=1)
        att = AcademicAttempt.objects.create(semester=sem, attempt_number=1, exam_type="REGULAR")

        s1 = Subject.objects.create(student=self.student, subject_code="CS101", subject_name="Math", default_credits=4)
        s2 = Subject.objects.create(student=self.student, subject_code="AUD101", subject_name="Env Studies", default_credits=0)

        SubjectAttempt.objects.create(subject=s1, academic_attempt=att, raw_grade="A", normalized_grade="A", grade_point=Decimal("9.00"), credits=Decimal("4.00"), is_pass=True)
        SubjectAttempt.objects.create(subject=s2, academic_attempt=att, raw_grade="EX", normalized_grade="EX", grade_point=Decimal("10.00"), credits=Decimal("0.00"), is_pass=True)

        res = CalculationEngine.reconcile_semester(sem)
        self.assertEqual(res.sgpa, Decimal("9.00"))
        self.assertEqual(res.total_credits_registered, Decimal("4.00"))

    def test_multi_semester_cgpa_weighted_calculation(self):
        """
        Semester 1: 20 credits, SGPA = 8.00 (Points = 160)
        Semester 2: 30 credits, SGPA = 9.00 (Points = 270)
        Cumulative CGPA must be (160 + 270) / (20 + 30) = 430 / 50 = 8.60
        (NOT simple average: (8.00 + 9.00) / 2 = 8.50)
        """
        sem1 = Semester.objects.create(student=self.student, semester_number=1)
        att1 = AcademicAttempt.objects.create(semester=sem1, attempt_number=1, exam_type="REGULAR")
        sub1 = Subject.objects.create(student=self.student, subject_code="S101", subject_name="Course 1", default_credits=20)
        SubjectAttempt.objects.create(subject=sub1, academic_attempt=att1, raw_grade="B", normalized_grade="B", grade_point=Decimal("8.00"), credits=Decimal("20.00"), is_pass=True)
        CalculationEngine.reconcile_semester(sem1)

        sem2 = Semester.objects.create(student=self.student, semester_number=2)
        att2 = AcademicAttempt.objects.create(semester=sem2, attempt_number=1, exam_type="REGULAR")
        sub2 = Subject.objects.create(student=self.student, subject_code="S201", subject_name="Course 2", default_credits=30)
        SubjectAttempt.objects.create(subject=sub2, academic_attempt=att2, raw_grade="A", normalized_grade="A", grade_point=Decimal("9.00"), credits=Decimal("30.00"), is_pass=True)
        CalculationEngine.reconcile_semester(sem2)

        summary = CalculationEngine.calculate_academic_summary(self.student)
        self.assertEqual(summary.cgpa, Decimal("8.60"))
        self.assertEqual(summary.total_credits_completed, Decimal("50.00"))

    def test_target_cgpa_achievability(self):
        """Test Target CGPA solver with achievable and unachievable targets."""
        # Setup student with 50 credits at 8.60 CGPA
        sem = Semester.objects.create(student=self.student, semester_number=1)
        att = AcademicAttempt.objects.create(semester=sem, attempt_number=1, exam_type="REGULAR")
        sub = Subject.objects.create(student=self.student, subject_code="GEN1", subject_name="Gen", default_credits=50)
        SubjectAttempt.objects.create(subject=sub, academic_attempt=att, raw_grade="B", normalized_grade="B", grade_point=Decimal("8.60"), credits=Decimal("50.00"), is_pass=True)
        CalculationEngine.reconcile_semester(sem)
        CalculationEngine.calculate_academic_summary(self.student)

        # Target 9.0 with 25 remaining credits:
        # Total = 75 credits. Target points = 75 * 9.0 = 675. Current points = 50 * 8.6 = 430.
        # Required points = 675 - 430 = 245. Required GPA = 245 / 25 = 9.80 (Achievable <= 10.0)
        result1 = AnalyticsService.calculate_target_requirement(self.student, target_cgpa=9.0, remaining_credits=25.0)
        self.assertTrue(result1['is_achievable'])
        self.assertEqual(result1['required_average_grade_point'], 9.80)

        # Target 9.5 with 25 remaining credits:
        # Target points = 75 * 9.5 = 712.5. Required points = 712.5 - 430 = 282.5.
        # Required GPA = 282.5 / 25 = 11.30 (Unachievable > 10.0)
        result2 = AnalyticsService.calculate_target_requirement(self.student, target_cgpa=9.5, remaining_credits=25.0)
        self.assertFalse(result2['is_achievable'])
