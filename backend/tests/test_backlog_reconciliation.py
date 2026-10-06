from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from apps.students.models import StudentProfile
from apps.grading.models import GradingSystem, GradeRule
from apps.semesters.models import Semester, AcademicAttempt
from apps.subjects.models import Subject, SubjectAttempt, EffectiveSubjectResult
from services.calculation.engine import CalculationEngine

User = get_user_model()

class BacklogReconciliationTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="santosh@university.edu", password="securepassword")
        self.grading_system = GradingSystem.objects.create(name="Default System", code="DEFAULT", is_default=True)
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
            full_name="Santosh Mora",
            registration_number="REG2024001",
            grading_system=self.grading_system
        )

    def test_semester_3_regular_and_supplementary_reconciliation(self):
        """
        Semester 3 Regular:
        - Mathematics: 4 credits, Grade A (9)
        - DBMS: 3 credits, Grade B (8)
        - Operating Systems: 4 credits, Grade F (0)
        - Networks: 3 credits, Grade A (9)
        Total Credits = 14. Points = 36 + 24 + 0 + 27 = 87. Regular SGPA = 87 / 14 = 6.21

        Then Supplementary:
        - Operating Systems: 4 credits, Grade B (8)

        Reconciled Semester 3:
        - Both attempts preserved
        - Effective OS = B
        - Total Credits = 14 (NO double counting!)
        - Points = 36 + 24 + 32 + 27 = 119. Effective SGPA = 119 / 14 = 8.50
        """
        semester = Semester.objects.create(student=self.student, semester_number=3)
        regular_attempt = AcademicAttempt.objects.create(semester=semester, attempt_number=1, exam_type="REGULAR")

        math = Subject.objects.create(student=self.student, subject_code="M301", subject_name="Mathematics", default_credits=4)
        dbms = Subject.objects.create(student=self.student, subject_code="CS301", subject_name="DBMS", default_credits=3)
        os = Subject.objects.create(student=self.student, subject_code="CS302", subject_name="Operating Systems", default_credits=4)
        cn = Subject.objects.create(student=self.student, subject_code="CS303", subject_name="Networks", default_credits=3)

        SubjectAttempt.objects.create(subject=math, academic_attempt=regular_attempt, raw_grade="A", normalized_grade="A", grade_point=Decimal("9.00"), credits=Decimal("4.00"), is_pass=True)
        SubjectAttempt.objects.create(subject=dbms, academic_attempt=regular_attempt, raw_grade="B", normalized_grade="B", grade_point=Decimal("8.00"), credits=Decimal("3.00"), is_pass=True)
        SubjectAttempt.objects.create(subject=os, academic_attempt=regular_attempt, raw_grade="F", normalized_grade="F", grade_point=Decimal("0.00"), credits=Decimal("4.00"), is_pass=False)
        SubjectAttempt.objects.create(subject=cn, academic_attempt=regular_attempt, raw_grade="A", normalized_grade="A", grade_point=Decimal("9.00"), credits=Decimal("3.00"), is_pass=True)

        res_reg = CalculationEngine.reconcile_semester(semester)
        self.assertEqual(res_reg.sgpa, Decimal("6.21"))
        self.assertEqual(res_reg.total_credits_registered, Decimal("14.00"))
        self.assertEqual(res_reg.total_credits_earned, Decimal("10.00"))
        self.assertTrue(res_reg.has_backlogs)

        # Later: Supplementary Attempt arrives containing ONLY Operating Systems
        supple_attempt = AcademicAttempt.objects.create(semester=semester, attempt_number=2, exam_type="SUPPLEMENTARY")
        SubjectAttempt.objects.create(
            subject=os,
            academic_attempt=supple_attempt,
            raw_grade="B",
            normalized_grade="B",
            grade_point=Decimal("8.00"),
            credits=Decimal("4.00"),
            is_pass=True
        )

        # Reconcile again
        res_supple = CalculationEngine.reconcile_semester(semester)

        # 1. Total credits must remain exactly 14 (NOT 18)
        self.assertEqual(res_supple.total_credits_registered, Decimal("14.00"))
        self.assertEqual(res_supple.total_credits_earned, Decimal("14.00"))

        # 2. Effective SGPA must be 8.50
        self.assertEqual(res_supple.sgpa, Decimal("8.50"))
        self.assertFalse(res_supple.has_backlogs)

        # 3. Both historical attempts must still exist
        all_os_attempts = SubjectAttempt.objects.filter(subject=os)
        self.assertEqual(all_os_attempts.count(), 2)
        grades = [a.normalized_grade for a in all_os_attempts]
        self.assertIn("F", grades)
        self.assertIn("B", grades)

        # 4. Effective result for OS must be B
        eff_os = EffectiveSubjectResult.objects.get(semester=semester, subject=os)
        self.assertEqual(eff_os.effective_grade, "B")
        self.assertEqual(eff_os.effective_grade_point, Decimal("8.00"))

    def test_student_fails_again_in_supplementary(self):
        """Regular = F, Supple 1 = F, Supple 2 = B."""
        semester = Semester.objects.create(student=self.student, semester_number=4)
        att1 = AcademicAttempt.objects.create(semester=semester, attempt_number=1, exam_type="REGULAR")
        att2 = AcademicAttempt.objects.create(semester=semester, attempt_number=2, exam_type="SUPPLEMENTARY")
        att3 = AcademicAttempt.objects.create(semester=semester, attempt_number=3, exam_type="SUPPLEMENTARY")

        sub = Subject.objects.create(student=self.student, subject_code="EE401", subject_name="Electrical", default_credits=3)
        SubjectAttempt.objects.create(subject=sub, academic_attempt=att1, raw_grade="F", normalized_grade="F", grade_point=Decimal("0.00"), credits=Decimal("3.00"), is_pass=False)
        SubjectAttempt.objects.create(subject=sub, academic_attempt=att2, raw_grade="F", normalized_grade="F", grade_point=Decimal("0.00"), credits=Decimal("3.00"), is_pass=False)
        SubjectAttempt.objects.create(subject=sub, academic_attempt=att3, raw_grade="B", normalized_grade="B", grade_point=Decimal("8.00"), credits=Decimal("3.00"), is_pass=True)

        res = CalculationEngine.reconcile_semester(semester)
        self.assertEqual(res.sgpa, Decimal("8.00"))
        self.assertEqual(res.total_credits_earned, Decimal("3.00"))
        self.assertEqual(SubjectAttempt.objects.filter(subject=sub).count(), 3)
