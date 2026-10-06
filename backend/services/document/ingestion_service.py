import os
from apps.gradesheets.models import OCRExtraction, OCRField
from services.cv.preprocessor import ImagePreprocessor
from services.ocr.provider import HybridOCRProvider
from services.extraction.header_detector import HeaderDetector
from services.extraction.table_extractor import TableExtractor

class IngestionService:
    """Orchestrates the multi-stage document intelligence and OCR pipeline."""

    @classmethod
    def process_gradesheet(cls, gradesheet, job=None, custom_semester=None, custom_exam_type=None):
        file_path = gradesheet.file.path
        ext = os.path.splitext(file_path)[-1].lower()

        # Step 1: Preprocessing
        if job:
            job.stage = 'PREPROCESSING'
            job.message = 'Enhancing image contrast and deskewing document...'
            job.save()

        # Step 2: OCR Text Extraction
        if job:
            job.stage = 'OCR_EXTRACTION'
            job.message = 'Running OCR engine on document layout...'
            job.save()

        ocr_engine = HybridOCRProvider()
        ocr_result = ocr_engine.extract_document(file_path)
        extracted_text = ocr_result.get('text', '')

        # Step 3: Header Analysis & Classification
        if job:
            job.stage = 'HEADER_DETECTION'
            job.message = 'Detecting semester, exam type, and institutional headings...'
            job.save()

        # Take first 1500 characters as upper/header region
        header_text = extracted_text[:1500] if len(extracted_text) > 1500 else extracted_text
        header_meta = HeaderDetector.extract_header_metadata(header_text)

        # Update GradeSheet with Header Findings
        gradesheet.raw_header_text = header_text
        gradesheet.document_type = header_meta['document_type']

        if custom_semester:
            gradesheet.detected_semester = custom_semester
            gradesheet.semester_confidence = 1.0
        else:
            gradesheet.detected_semester = header_meta['semester']
            gradesheet.semester_confidence = header_meta['semester_confidence']

        if custom_exam_type:
            gradesheet.detected_exam_type = custom_exam_type
            gradesheet.exam_type_confidence = 1.0
        else:
            gradesheet.detected_exam_type = header_meta['exam_type']
            gradesheet.exam_type_confidence = header_meta['exam_type_confidence']

        gradesheet.extracted_student_name = header_meta['student_name']
        gradesheet.extracted_reg_no = header_meta['registration_number']
        gradesheet.extracted_session = header_meta['session']

        # Validate Student Identity
        student_profile = gradesheet.student
        if student_profile.registration_number and header_meta['registration_number']:
            if student_profile.registration_number.upper() != header_meta['registration_number'].upper():
                gradesheet.student_match_verified = False

        # Step 4: Table Extraction
        if job:
            job.stage = 'TABLE_EXTRACTION'
            job.message = 'Parsing subjects, credits, and grades...'
            job.save()

        subjects = TableExtractor.extract_subjects_from_text(extracted_text)

        # Save OCRExtraction
        extraction, _ = OCRExtraction.objects.update_or_create(
            gradesheet=gradesheet,
            defaults={
                'raw_text': extracted_text,
                'extracted_data': {
                    'header': header_meta,
                    'subjects': subjects,
                },
                'overall_confidence': ocr_result.get('confidence', 0.85)
            }
        )

        # Save individual OCRFields for audit trail
        OCRField.objects.filter(extraction=extraction).delete()
        for idx, sub in enumerate(subjects):
            OCRField.objects.create(
                extraction=extraction,
                field_name=f"subject_{idx+1}_grade",
                raw_value=sub['raw_grade'],
                normalized_value=sub['normalized_grade'],
                confidence=sub['confidence'],
                needs_review=sub['needs_review']
            )

        # Update Job Status
        if job:
            job.status = 'REVIEW_REQUIRED' if any(s['needs_review'] for s in subjects) else 'COMPLETED'
            job.stage = 'VERIFICATION_READY'
            job.message = 'Document processed. Ready for user verification.'
            job.save()

        gradesheet.upload_status = 'REVIEW_REQUIRED' if any(s['needs_review'] for s in subjects) else 'VERIFIED'
        gradesheet.save()

        return {
            'document_type': gradesheet.document_type,
            'semester': gradesheet.detected_semester,
            'exam_type': gradesheet.detected_exam_type,
            'subjects_count': len(subjects),
            'subjects': subjects,
            'student_match': gradesheet.student_match_verified
        }
