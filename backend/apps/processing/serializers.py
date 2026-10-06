from rest_framework import serializers
from .models import ProcessingJob

class ProcessingJobSerializer(serializers.ModelSerializer):
    gradesheet_filename = serializers.CharField(source='gradesheet.original_filename', read_only=True)
    detected_semester = serializers.IntegerField(source='gradesheet.detected_semester', read_only=True)
    detected_exam_type = serializers.CharField(source='gradesheet.detected_exam_type', read_only=True)

    class Meta:
        model = ProcessingJob
        fields = (
            'id', 'student', 'gradesheet', 'gradesheet_filename',
            'status', 'stage', 'message', 'detected_semester',
            'detected_exam_type', 'created_at', 'updated_at'
        )
