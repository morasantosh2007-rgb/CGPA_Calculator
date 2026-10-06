from decimal import Decimal
from apps.semesters.models import Semester, AcademicAttempt
from apps.subjects.models import Subject, SubjectAttempt
from services.matching.subject_matcher import SubjectMatcher
from services.calculation.engine import CalculationEngine

class AttemptReconciler:
    """Reconciles student academic attempts and guarantees credit integrity."""

    @classmethod
    def commit_verified_attempt(cls, gradesheet, semester_num, exam_type, subjects_data):
        student = gradesheet.student

        # 1. Locate or create parent Semester
        semester, _ = Semester.objects.get_or_create(
            student=student,
            semester_number=semester_num,
            defaults={'academic_year': gradesheet.extracted_session or ''}
        )

        # 2. Determine Attempt Number
        existing_attempts = semester.attempts.all().order_by('attempt_number')
        attempt_num = existing_attempts.count() + 1

        # 3. Create Academic Attempt
        academic_attempt = AcademicAttempt.objects.create(
            semester=semester,
            attempt_number=attempt_num,
            exam_type=exam_type,
            raw_exam_type=gradesheet.raw_header_text[:100],
            academic_session=gradesheet.extracted_session or '',
            is_verified=True
        )

        # Link gradesheet to attempt
        gradesheet.academic_attempt = academic_attempt
        gradesheet.save()

        # 4. Process Subjects
        grading_rules = {r.grade: r for r in student.grading_system.rules.all()} if student.grading_system else {}

        for item in subjects_data:
            code = (item.get('code') or '').strip().upper()
            title = (item.get('name') or item.get('title') or '').strip()
            credits = Decimal(str(item.get('credits', 3.0)))
            norm_grade = (item.get('normalized_grade') or item.get('grade', 'F')).strip().upper()
            
            # Map rule
            rule = grading_rules.get(norm_grade)
            if rule:
                gp = rule.grade_point
                is_pass = rule.is_pass
            else:
                from services.extraction.table_extractor import TableExtractor
                fallback_val = item.get('grade_point', TableExtractor.VALID_GRADES.get(norm_grade, 0.0))
                gp = Decimal(str(fallback_val))
                is_pass = norm_grade != 'F'

            # Match or create Subject
            existing_subjects = Subject.objects.filter(student=student)
            matched_subject = None
            for es in existing_subjects:
                if SubjectMatcher.is_match(es.subject_code, es.subject_name, code, title):
                    matched_subject = es
                    break

            if not matched_subject:
                matched_subject = Subject.objects.create(
                    student=student,
                    subject_code=code,
                    normalized_code=SubjectMatcher.normalize_code(code),
                    subject_name=title,
                    default_credits=credits
                )

            # Record SubjectAttempt
            SubjectAttempt.objects.create(
                subject=matched_subject,
                academic_attempt=academic_attempt,
                source_gradesheet=gradesheet,
                raw_grade=item.get('raw_grade', norm_grade),
                normalized_grade=norm_grade,
                grade_point=gp,
                credits=credits,
                is_pass=is_pass,
                confidence=float(item.get('confidence', 1.0)),
                user_corrected=bool(item.get('user_corrected', False))
            )

        # 5. Reconcile Semester and Recalculate Standing
        sem_res = CalculationEngine.reconcile_semester(semester)
        summary = CalculationEngine.calculate_academic_summary(student)

        return {
            'semester_id': str(semester.id),
            'attempt_id': str(academic_attempt.id),
            'attempt_number': attempt_num,
            'sgpa': float(sem_res.sgpa),
            'cgpa': float(summary.cgpa),
        }
