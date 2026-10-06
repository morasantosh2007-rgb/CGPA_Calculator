from rest_framework import serializers
from .models import Semester, AcademicAttempt

class AcademicAttemptSerializer(serializers.ModelSerializer):
    subject_attempts_count = serializers.SerializerMethodField()
    gradesheet_file_url = serializers.SerializerMethodField()
    gradesheet_filename = serializers.SerializerMethodField()

    class Meta:
        model = AcademicAttempt
        fields = (
            'id', 'semester', 'attempt_number', 'exam_type',
            'raw_exam_type', 'academic_session', 'exam_date',
            'is_verified', 'created_at', 'subject_attempts_count',
            'gradesheet_file_url', 'gradesheet_filename'
        )

    def get_subject_attempts_count(self, obj):
        return obj.subject_attempts.count()

    def get_gradesheet_file_url(self, obj):
        sheet = obj.gradesheets.first()
        if sheet and sheet.file:
            return sheet.file.url
        return None

    def get_gradesheet_filename(self, obj):
        sheet = obj.gradesheets.first()
        if sheet:
            return sheet.original_filename
        return None

class SemesterSerializer(serializers.ModelSerializer):
    attempts = AcademicAttemptSerializer(many=True, read_only=True)
    sgpa = serializers.SerializerMethodField()
    total_credits = serializers.SerializerMethodField()
    effective_subjects_count = serializers.SerializerMethodField()

    class Meta:
        model = Semester
        fields = (
            'id', 'student', 'semester_number', 'academic_year',
            'status', 'created_at', 'updated_at',
            'attempts', 'sgpa', 'total_credits', 'effective_subjects_count'
        )
        read_only_fields = ('student',)

    def get_sgpa(self, obj):
        res = getattr(obj, 'result', None)
        return float(res.sgpa) if res else None

    def get_total_credits(self, obj):
        res = getattr(obj, 'result', None)
        return float(res.total_credits_registered) if res else 0.0

    def get_effective_subjects_count(self, obj):
        return obj.effective_results.count()
