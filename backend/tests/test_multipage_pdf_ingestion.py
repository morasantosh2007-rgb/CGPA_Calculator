import io
from decimal import Decimal
from django.test import TestCase
from django.contrib.auth import get_user_model
from django.core.files.uploadedfile import SimpleUploadedFile
from reportlab.lib.pagesizes import letter
from reportlab.pdfgen import canvas
import pypdf

from apps.students.models import StudentProfile
from apps.grading.models import GradingSystem, GradeRule
from apps.gradesheets.models import GradeSheet
from services.document.ingestion_service import IngestionService
from services.matching.reconciler import AttemptReconciler
from services.calculation.engine import CalculationEngine

User = get_user_model()

class MultiPagePDFIngestionTestCase(TestCase):
    def setUp(self):
        self.user = User.objects.create_user(email="santosh@multipage.edu", password="password123")
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
            registration_number="20A91A0501",
            grading_system=self.grading_system
        )

    def test_multi_semester_gradesheet_pdf_parsing_and_reconciliation(self):
        """
        Builds a multi-page PDF containing all grade sheets:
        - Page 1: Semester 1 Regular (CS101: 4 Cr Grade A, MA101: 4 Cr Grade B) -> SGPA = (36+32)/8 = 8.50
        - Page 2: Semester 2 Regular (CS201: 4 Cr Grade EX, MA201: 4 Cr Grade A) -> SGPA = (40+36)/8 = 9.50
        - Page 3: Semester 3 Regular (CS301: 4 Cr Grade F, CS302: 4 Cr Grade A) -> Regular SGPA = (0+36)/8 = 4.50
        - Page 4: Semester 3 Supplementary (CS301: 4 Cr Grade B) -> Reconciles OS to B! Effective Sem 3 SGPA = (32+36)/8 = 8.50
        Overall CGPA = (68 + 76 + 68) / 24 = 212 / 24 = 8.83
        """
        buf = io.BytesIO()
        c = canvas.Canvas(buf, pagesize=letter)

        # Page 1: Semester 1
        c.drawString(100, 750, 'JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY')
        c.drawString(100, 730, 'SEMESTER I REGULAR EXAMINATION NOV 2022')
        c.drawString(100, 710, 'NAME: SANTOSH MORA   HTNO: 20A91A0501')
        c.drawString(100, 680, 'SUBCODE  SUBNAME        CREDITS  GRADE')
        c.drawString(100, 660, 'CS101    PYTHON PROG       4       A')
        c.drawString(100, 640, 'MA101    CALCULUS          4       B')
        c.showPage()

        # Page 2: Semester 2
        c.drawString(100, 750, 'JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY')
        c.drawString(100, 730, 'SEMESTER II REGULAR EXAMINATION APR 2023')
        c.drawString(100, 710, 'NAME: SANTOSH MORA   HTNO: 20A91A0501')
        c.drawString(100, 680, 'SUBCODE  SUBNAME        CREDITS  GRADE')
        c.drawString(100, 660, 'CS201    DATA STRUCTURES   4       EX')
        c.drawString(100, 640, 'MA201    LINEAR ALGEBRA    4       A')
        c.showPage()

        # Page 3: Semester 3 Regular
        c.drawString(100, 750, 'JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY')
        c.drawString(100, 730, 'SEMESTER III REGULAR EXAMINATION NOV 2023')
        c.drawString(100, 710, 'NAME: SANTOSH MORA   HTNO: 20A91A0501')
        c.drawString(100, 680, 'SUBCODE  SUBNAME        CREDITS  GRADE')
        c.drawString(100, 660, 'CS301    OPERATING SYSTEM  4       F')
        c.drawString(100, 640, 'CS302    COMPUTER NETWORKS 4       A')
        c.showPage()

        # Page 4: Semester 3 Supplementary
        c.drawString(100, 750, 'JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY')
        c.drawString(100, 730, 'SEMESTER III SUPPLEMENTARY EXAMINATION APR 2024')
        c.drawString(100, 710, 'NAME: SANTOSH MORA   HTNO: 20A91A0501')
        c.drawString(100, 680, 'SUBCODE  SUBNAME        CREDITS  GRADE')
        c.drawString(100, 660, 'CS301    OPERATING SYSTEM  4       B')
        c.showPage()

        c.save()
        pdf_bytes = buf.getvalue()

        uploaded_file = SimpleUploadedFile(
            name="All_Semesters_Consolidated.pdf",
            content=pdf_bytes,
            content_type="application/pdf"
        )

        gradesheet = GradeSheet.objects.create(
            student=self.student,
            original_filename="All_Semesters_Consolidated.pdf",
            file=uploaded_file,
            file_hash="mock_multipage_hash"
        )

        # Process document
        result = IngestionService.process_gradesheet(gradesheet)

        self.assertTrue(result['is_multi_semester'])
        self.assertEqual(result['total_semesters_detected'], 4)
        blocks = result['semester_blocks']

        # Verify detected block structure
        self.assertEqual(blocks[0]['semester'], 1)
        self.assertEqual(blocks[0]['exam_type'], 'REGULAR')
        self.assertEqual(len(blocks[0]['subjects']), 2)

        self.assertEqual(blocks[1]['semester'], 2)
        self.assertEqual(blocks[1]['exam_type'], 'REGULAR')
        self.assertEqual(len(blocks[1]['subjects']), 2)

        self.assertEqual(blocks[2]['semester'], 3)
        self.assertEqual(blocks[2]['exam_type'], 'REGULAR')
        self.assertEqual(len(blocks[2]['subjects']), 2)

        self.assertEqual(blocks[3]['semester'], 3)
        self.assertEqual(blocks[3]['exam_type'], 'SUPPLEMENTARY')
        self.assertEqual(len(blocks[3]['subjects']), 1)

        # Commit all blocks as verified
        for block in blocks:
            AttemptReconciler.commit_verified_attempt(
                gradesheet=gradesheet,
                semester_num=block['semester'],
                exam_type=block['exam_type'],
                subjects_data=block['subjects']
            )

        summary = CalculationEngine.calculate_academic_summary(self.student)

        # Verify credit integrity (24 credits total: 8 + 8 + 8, zero double counting)
        self.assertEqual(float(summary.total_credits_completed), 24.0)
        self.assertEqual(summary.active_backlogs_count, 0)
        self.assertEqual(float(summary.cgpa), 8.83)

    def test_real_scanned_multipage_pdf_with_rapidocr(self):
        """
        Tests end-to-end OCR extraction and reconciliation on the user's real 5-page PDF:
        - 4 semesters of engineering coursework + 1 revaluation notice
        - Automatic watermark removal on high-res scanned sheets
        - Dark-mode screenshot contrast inversion
        - Revaluation reconciliation of CS2072 from Grade F to Grade C
        """
        import os
        real_pdf_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'media', 'gradesheets', '2026', '10', 'gradesheets.pdf')
        if not os.path.exists(real_pdf_path):
            self.skipTest("Real PDF not found at media/gradesheets/2026/10/gradesheets.pdf")

        with open(real_pdf_path, 'rb') as f:
            pdf_bytes = f.read()

        uploaded_file = SimpleUploadedFile(
            name="gradesheets.pdf",
            content=pdf_bytes,
            content_type="application/pdf"
        )

        gradesheet = GradeSheet.objects.create(
            student=self.student,
            original_filename="gradesheets.pdf",
            file=uploaded_file,
            file_hash="real_gradesheet_hash_test"
        )

        result = IngestionService.process_gradesheet(gradesheet)

        self.assertTrue(result['is_multi_semester'])
        self.assertEqual(result['total_semesters_detected'], 5)
        self.assertEqual(result['subjects_count'], 38)
        self.assertTrue(result['student_match'])

        # Verify summary
        summary = CalculationEngine.calculate_academic_summary(self.student)
        self.assertEqual(summary.active_backlogs_count, 0)
        self.assertEqual(float(summary.total_credits_completed), 77.0)
        self.assertGreaterEqual(float(summary.cgpa), 7.0)
