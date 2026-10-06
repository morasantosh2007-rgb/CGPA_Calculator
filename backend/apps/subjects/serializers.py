from rest_framework import serializers
from .models import Subject, SubjectAttempt, EffectiveSubjectResult

class SubjectAttemptSerializer(serializers.ModelSerializer):
    exam_type = serializers.CharField(source='academic_attempt.exam_type', read_only=True)
    attempt_number = serializers.IntegerField(source='academic_attempt.attempt_number', read_only=True)

    class Meta:
        model = SubjectAttempt
        fields = (
            'id', 'subject', 'academic_attempt', 'exam_type', 'attempt_number',
            'raw_grade', 'normalized_grade', 'grade_point', 'credits',
            'is_pass', 'confidence', 'user_corrected', 'original_value', 'created_at'
        )

class EffectiveSubjectResultSerializer(serializers.ModelSerializer):
    subject_code = serializers.CharField(source='subject.subject_code', read_only=True)
    subject_name = serializers.CharField(source='subject.subject_name', read_only=True)

    class Meta:
        model = EffectiveSubjectResult
        fields = (
            'id', 'semester', 'subject', 'subject_code', 'subject_name',
            'selected_attempt', 'effective_grade', 'effective_grade_point',
            'effective_credits', 'is_pass', 'updated_at'
        )

class SubjectSerializer(serializers.ModelSerializer):
    attempts = SubjectAttemptSerializer(many=True, read_only=True)

    class Meta:
        model = Subject
        fields = (
            'id', 'subject_code', 'normalized_code', 'subject_name',
            'default_credits', 'created_at', 'attempts'
        )
