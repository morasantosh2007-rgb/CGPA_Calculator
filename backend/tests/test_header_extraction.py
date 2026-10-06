from django.test import TestCase
from services.extraction.header_detector import HeaderDetector
from services.extraction.table_extractor import TableExtractor

class HeaderAndTableExtractionTestCase(TestCase):
    def test_semester_detection_variations(self):
        cases = [
            ("JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY\nSEMESTER III REGULAR EXAMINATION NOV 2023", 3, "REGULAR"),
            ("JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY\nIII B.TECH REGULAR EXAMINATION", 3, "REGULAR"),
            ("OSMANIA UNIVERSITY\nTHIRD SEMESTER SUPPLEMENTARY EXAMINATION APRIL 2024", 3, "SUPPLEMENTARY"),
            ("ANDHRA UNIVERSITY\n4TH SEMESTER BACKLOG EXAMINATION RESULTS", 4, "BACKLOG"),
            ("ANNA UNIVERSITY\nSEMESTER-VI REVALUATION RESULTS MAY 2023", 6, "REVALUATION"),
            ("DELHI UNIVERSITY\nSTATEMENT OF MARKS\nSEMESTER 2 REGULAR EXAMINATION", 2, "REGULAR"),
        ]

        for text, expected_sem, expected_exam in cases:
            meta = HeaderDetector.extract_header_metadata(text)
            self.assertEqual(meta['semester'], expected_sem, f"Failed for text: {text}")
            self.assertEqual(meta['exam_type'], expected_exam, f"Failed for exam type: {text}")

    def test_grade_normalization(self):
        cases = [
            ("EX", "EX", 10.0, True, False),
            ("Ex", "EX", 10.0, True, False),
            ("E-X", "EX", 10.0, True, False),
            ("A", "A", 9.0, True, False),
            ("B", "B", 8.0, True, False),
            ("M", "M", 4.0, True, False),
            ("F", "F", 0.0, False, False),
            ("G", "UNKNOWN_GRADE", 0.0, False, True),  # Unknown grade flags review
        ]

        for raw, exp_norm, exp_gp, exp_pass, exp_review in cases:
            norm, gp, is_pass, needs_review = TableExtractor.normalize_grade(raw)
            self.assertEqual(norm, exp_norm, f"Failed on raw grade {raw}")
            self.assertEqual(gp, exp_gp, f"Failed on GP for {raw}")
            self.assertEqual(is_pass, exp_pass, f"Failed on pass for {raw}")
            self.assertEqual(needs_review, exp_review, f"Failed on review flag for {raw}")

    def test_table_line_parsing(self):
        raw_text = """
        CS301  Object Oriented Programming  4.0  A
        CS302  Computer Organization        3.0  B
        CS303  Operating Systems            4.0  EX
        CS304  Database Management Systems  3.0  M
        """
        subjects = TableExtractor.extract_subjects_from_text(raw_text)
        self.assertEqual(len(subjects), 4)
        self.assertEqual(subjects[0]['code'], "CS301")
        self.assertEqual(subjects[0]['normalized_grade'], "A")
        self.assertEqual(subjects[2]['normalized_grade'], "EX")
        self.assertEqual(subjects[3]['normalized_grade'], "M")
        self.assertEqual(subjects[3]['grade_point'], 4.0)

    def test_pdf_extraction_and_student_metadata(self):
        import io
        from reportlab.lib.pagesizes import letter
        from reportlab.pdfgen import canvas
        from services.ocr.provider import DigitalPDFProvider

        buf = io.BytesIO()
        c = canvas.Canvas(buf, pagesize=letter)
        c.drawString(100, 750, "JAWAHARLAL NEHRU TECHNOLOGICAL UNIVERSITY")
        c.drawString(100, 730, "SEMESTER III REGULAR EXAMINATION RESULT")
        c.drawString(100, 710, "STUDENT NAME: SANTOSH MORA   HTNO: 20A91A0501")
        c.drawString(100, 680, "SUBCODE  SUBNAME        CREDITS  GRADE")
        c.drawString(100, 660, "CS301    DATA STRUCTURES   4       A")
        c.drawString(100, 640, "CS302    DIGITAL LOGIC     3       B")
        c.save()

        buf.seek(0)
        pdf_provider = DigitalPDFProvider()
        text = pdf_provider.extract_text(buf)

        self.assertIn("DATA STRUCTURES", text)
        self.assertIn("SEMESTER III", text)

        meta = HeaderDetector.extract_header_metadata(text)
        self.assertEqual(meta['semester'], 3)
        self.assertEqual(meta['exam_type'], 'REGULAR')
        self.assertEqual(meta['registration_number'], '20A91A0501')
        self.assertEqual(meta['student_name'], 'SANTOSH MORA')
        self.assertIn('TECHNOLOGICAL UNIVERSITY', meta['institution'])
