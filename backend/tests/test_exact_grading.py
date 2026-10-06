from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from apps.students.models import StudentProfile
from apps.grading.models import GradingSystem, GradeRule
from apps.semesters.models import Semester, AcademicAttempt
from apps.subjects.models import Subject, SubjectAttempt
from services.calculation.engine import CalculationEngine

User = get_user_model()

class ExactGradingSystemTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="student@university.edu", password="password123")
        self.grading_system = GradingSystem.objects.create(
            name="Exact 10-Point Scale",
            code="EXACT_SCALE",
            is_default=True
        )
        # Seed exact grading rules
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
            GradeRule.objects.create(
                grading_system=self.grading_system,
                grade=grade,
                grade_point=gp,
                is_pass=is_pass
            )

        self.student = StudentProfile.objects.create(
            user=self.user,
            full_name="Santosh Mora",
            registration_number="REG2024001",
            grading_system=self.grading_system
        )

    def test_exact_sgpa_calculation(self):
        """
        Subject 1: Credits = 4, Grade = EX, GP = 10
        Subject 2: Credits = 3, Grade = A,  GP = 9
        Subject 3: Credits = 3, Grade = B,  GP = 8
        Calculation: (4*10 + 3*9 + 3*8) / 10 = (40 + 27 + 24) / 10 = 91 / 10 = 9.10
        """
        semester = Semester.objects.create(student=self.student, semester_number=1)
        attempt = AcademicAttempt.objects.create(semester=semester, attempt_number=1, exam_type="REGULAR")

        s1 = Subject.objects.create(student=self.student, subject_code="CS101", subject_name="Subject 1", default_credits=4)
        s2 = Subject.objects.create(student=self.student, subject_code="CS102", subject_name="Subject 2", default_credits=3)
        s3 = Subject.objects.create(student=self.student, subject_code="CS103", subject_name="Subject 3", default_credits=3)

        SubjectAttempt.objects.create(
            subject=s1, academic_attempt=attempt, raw_grade="EX",
            normalized_grade="EX", grade_point=Decimal("10.00"), credits=Decimal("4.00"), is_pass=True
        )
        SubjectAttempt.objects.create(
            subject=s2, academic_attempt=attempt, raw_grade="A",
            normalized_grade="A", grade_point=Decimal("9.00"), credits=Decimal("3.00"), is_pass=True
        )
        SubjectAttempt.objects.create(
            subject=s3, academic_attempt=attempt, raw_grade="B",
            normalized_grade="B", grade_point=Decimal("8.00"), credits=Decimal("3.00"), is_pass=True
        )

        res = CalculationEngine.reconcile_semester(semester)
        self.assertEqual(res.sgpa, Decimal("9.10"))
        self.assertEqual(res.total_credits_registered, Decimal("10.00"))
        self.assertEqual(res.total_credits_earned, Decimal("10.00"))
        self.assertFalse(res.has_backlogs)

    def test_m_grade_is_valid_four_points(self):
        """M grade must evaluate to exactly 4.0 GP and count as a passing grade."""
        m_rule = GradeRule.objects.get(grading_system=self.grading_system, grade='M')
        self.assertEqual(m_rule.grade_point, Decimal('4.00'))
        self.assertTrue(m_rule.is_pass)
