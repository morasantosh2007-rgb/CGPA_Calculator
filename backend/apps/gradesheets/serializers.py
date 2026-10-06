from rest_framework import serializers
from .models import GradeSheet, OCRExtraction, OCRField

class OCRFieldSerializer(serializers.ModelSerializer):
    class Meta:
        model = OCRField
        fields = (
            'id', 'field_name', 'raw_value', 'normalized_value',
            'confidence', 'bounding_box', 'needs_review', 'user_corrected'
        )

class OCRExtractionSerializer(serializers.ModelSerializer):
    fields = OCRFieldSerializer(many=True, read_only=True)

    class Meta:
        model = OCRExtraction
        fields = ('id', 'raw_text', 'extracted_data', 'overall_confidence', 'fields')

class GradeSheetSerializer(serializers.ModelSerializer):
    extraction = OCRExtractionSerializer(read_only=True)

    class Meta:
        model = GradeSheet
        fields = (
            'id', 'original_filename', 'file', 'document_type',
            'upload_status', 'is_duplicate',
            'detected_semester', 'semester_confidence',
            'detected_exam_type', 'exam_type_confidence',
            'extracted_student_name', 'extracted_reg_no',
            'extracted_institution', 'extracted_session',
            'student_match_verified', 'created_at', 'extraction'
        )
        read_only_fields = ('student', 'file_hash', 'upload_status')

class GradeSheetUploadSerializer(serializers.Serializer):
    file = serializers.FileField(required=True)
    custom_semester = serializers.IntegerField(required=False, min_value=1, max_value=12)
    custom_exam_type = serializers.CharField(required=False)
