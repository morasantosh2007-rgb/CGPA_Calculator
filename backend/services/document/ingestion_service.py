import os
import re
from apps.gradesheets.models import OCRExtraction, OCRField
from services.cv.preprocessor import ImagePreprocessor
from services.ocr.provider import HybridOCRProvider
from services.extraction.header_detector import HeaderDetector
from services.extraction.table_extractor import TableExtractor

class IngestionService:
    """Orchestrates the multi-stage document intelligence and OCR pipeline with multi-semester support."""

    @classmethod
    def process_gradesheet(cls, gradesheet, job=None, custom_semester=None, custom_exam_type=None):
        file_path = gradesheet.file.path
        ext = os.path.splitext(file_path)[-1].lower()

        # Step 1: Preprocessing
        if job:
            job.stage = 'PREPROCESSING'
            job.message = 'Enhancing image contrast and analyzing document layout...'
            job.save()

        # Step 2: OCR Text Extraction
        if job:
            job.stage = 'OCR_EXTRACTION'
            job.message = 'Running OCR engine on document layout...'
            job.save()

        ocr_engine = HybridOCRProvider()
        ocr_result = ocr_engine.extract_document(file_path)
        extracted_text = ocr_result.get('text', '')
        pages_data = ocr_result.get('pages', [])

        # Step 3: Header Analysis & Multi-Semester Parsing
        if job:
            job.stage = 'HEADER_DETECTION'
            job.message = 'Detecting semesters, examination attempts, and institutional headings...'
            job.save()

        # Take first 1500 characters as document-level header
        header_text = extracted_text[:1500] if len(extracted_text) > 1500 else extracted_text
        header_meta = HeaderDetector.extract_header_metadata(header_text)

        semester_blocks = []

        # 1. Multi-page document check (e.g. multi-page PDF with all semesters/backlogs)
        if pages_data and len(pages_data) > 1:
            for p in pages_data:
                ptxt = p.get('text', '').strip()
                if not ptxt:
                    continue
                pmeta = HeaderDetector.extract_header_metadata(ptxt[:1500])
                psubjects = TableExtractor.extract_subjects_from_text(ptxt)

                if pmeta.get('semester'):
                    semester_blocks.append({
                        'page_number': p.get('page_number', 1),
                        'semester': pmeta['semester'],
                        'semester_confidence': pmeta['semester_confidence'],
                        'exam_type': pmeta['exam_type'],
                        'raw_exam_type': pmeta['raw_exam_type'],
                        'academic_session': pmeta['session'],
                        'student_name': pmeta['student_name'],
                        'registration_number': pmeta['registration_number'],
                        'subjects': psubjects,
                    })
                elif psubjects:
                    if semester_blocks:
                        semester_blocks[-1]['subjects'].extend(psubjects)
                    else:
                        semester_blocks.append({
                            'page_number': p.get('page_number', 1),
                            'semester': 1,
                            'semester_confidence': 0.60,
                            'exam_type': 'REGULAR',
                            'raw_exam_type': 'REGULAR',
                            'academic_session': '',
                            'student_name': '',
                            'registration_number': '',
                            'subjects': psubjects,
                        })

        # 2. Check if a single page or continuous text contains multiple semester sections
        if len(semester_blocks) <= 1:
            parts = re.split(
                r'(?=(?:(?:SEMESTER|SEM)[\s\-:]+[IVXLCDM\d]+|\b[IVXLCDM\d]+(?:ST|ND|RD|TH)?[\s\-]+(?:SEMESTER|SEM)\b))',
                extracted_text,
                flags=re.IGNORECASE
            )
            valid_parts = [part.strip() for part in parts if part.strip()]
            if len(valid_parts) > 1:
                section_blocks = []
                for idx, part in enumerate(valid_parts):
                    pmeta = HeaderDetector.extract_header_metadata(part[:1500])
                    psubjects = TableExtractor.extract_subjects_from_text(part)
                    if pmeta.get('semester') and psubjects:
                        section_blocks.append({
                            'page_number': idx + 1,
                            'semester': pmeta['semester'],
                            'semester_confidence': pmeta['semester_confidence'],
                            'exam_type': pmeta['exam_type'],
                            'raw_exam_type': pmeta['raw_exam_type'],
                            'academic_session': pmeta['session'],
                            'student_name': pmeta['student_name'],
                            'registration_number': pmeta['registration_number'],
                            'subjects': psubjects,
                        })
                if len(section_blocks) > 1:
                    semester_blocks = section_blocks

        # 3. Fallback to standard single block if no multi-semester sections found
        if not semester_blocks:
            subjects = TableExtractor.extract_subjects_from_text(extracted_text)
            semester_blocks.append({
                'page_number': 1,
                'semester': custom_semester or header_meta['semester'] or 1,
                'semester_confidence': header_meta['semester_confidence'],
                'exam_type': custom_exam_type or header_meta['exam_type'] or 'REGULAR',
                'raw_exam_type': header_meta['raw_exam_type'],
                'academic_session': header_meta['session'],
                'student_name': header_meta['student_name'],
                'registration_number': header_meta['registration_number'],
                'subjects': subjects,
            })

        # Aggregate all extracted subjects
        all_subjects = []
        for b in semester_blocks:
            all_subjects.extend(b['subjects'])

        primary_block = semester_blocks[0]
        gradesheet.raw_header_text = header_text
        gradesheet.document_type = 'TRANSCRIPT' if len(semester_blocks) > 1 else header_meta['document_type']
        gradesheet.detected_semester = custom_semester or primary_block['semester']
        gradesheet.semester_confidence = primary_block['semester_confidence']
        gradesheet.detected_exam_type = custom_exam_type or primary_block['exam_type']
        gradesheet.exam_type_confidence = 0.95 if custom_exam_type else primary_block.get('semester_confidence', 0.85)

        detected_reg = header_meta['registration_number'] or primary_block.get('registration_number', '')
        detected_name = header_meta['student_name'] or primary_block.get('student_name', '')
        gradesheet.extracted_student_name = detected_name
        gradesheet.extracted_reg_no = detected_reg
        gradesheet.extracted_session = header_meta['session'] or primary_block.get('academic_session', '')

        # Validate Student Identity
        student_profile = gradesheet.student
        if student_profile.registration_number and detected_reg:
            if student_profile.registration_number.upper() != detected_reg.upper():
                gradesheet.student_match_verified = False

        # Save OCRExtraction with full semester blocks audit
        extraction, _ = OCRExtraction.objects.update_or_create(
            gradesheet=gradesheet,
            defaults={
                'raw_text': extracted_text,
                'extracted_data': {
                    'header': header_meta,
                    'is_multi_semester': len(semester_blocks) > 1,
                    'semester_blocks': semester_blocks,
                    'subjects': all_subjects,
                },
                'overall_confidence': ocr_result.get('confidence', 0.85)
            }
        )

        # Save individual OCRFields for audit trail
        OCRField.objects.filter(extraction=extraction).delete()
        for idx, sub in enumerate(all_subjects):
            OCRField.objects.create(
                extraction=extraction,
                field_name=f"subject_{idx+1}_{sub.get('code') or 'course'}_grade",
                raw_value=sub['raw_grade'],
                normalized_value=sub['normalized_grade'],
                confidence=sub['confidence'],
                needs_review=sub['needs_review']
            )

        # Update Job Status
        has_review = any(s['needs_review'] for s in all_subjects)
        if job:
            job.status = 'REVIEW_REQUIRED' if has_review else 'COMPLETED'
            job.stage = 'VERIFICATION_READY'
            job.message = f"Parsed {len(semester_blocks)} semester attempt(s) containing {len(all_subjects)} subject(s)."
            job.save()

        gradesheet.upload_status = 'REVIEW_REQUIRED' if has_review else 'VERIFIED'
        gradesheet.save()

        return {
            'document_type': gradesheet.document_type,
            'is_multi_semester': len(semester_blocks) > 1,
            'semester_blocks': semester_blocks,
            'total_semesters_detected': len(semester_blocks),
            'semester': gradesheet.detected_semester,
            'exam_type': gradesheet.detected_exam_type,
            'subjects_count': len(all_subjects),
            'subjects': all_subjects,
            'student_match': gradesheet.student_match_verified,
            'student_name': gradesheet.extracted_student_name,
            'registration_number': gradesheet.extracted_reg_no,
        }
