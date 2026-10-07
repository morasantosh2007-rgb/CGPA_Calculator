import hashlib
from rest_framework import status, permissions
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.parsers import MultiPartParser, FormParser
from .models import GradeSheet, OCRExtraction, OCRField
from .serializers import GradeSheetSerializer, GradeSheetUploadSerializer
from apps.processing.models import ProcessingJob
from services.document.ingestion_service import IngestionService
from apps.students.utils import get_active_student_profile

class GradeSheetUploadView(APIView):
    permission_classes = [permissions.AllowAny]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = GradeSheetUploadSerializer(data=request.data)
        if not serializer.is_valid():
            return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

        uploaded_file = serializer.validated_data['file']
        student_profile = get_active_student_profile(request)

        # Compute SHA-256 Hash
        hasher = hashlib.sha256()
        for chunk in uploaded_file.chunks():
            hasher.update(chunk)
        file_hash = hasher.hexdigest()

        # Duplicate check per student
        existing = GradeSheet.objects.filter(student=student_profile, file_hash=file_hash).first()
        if existing:
            extraction = getattr(existing, 'extraction', None)
            extracted_data = extraction.extracted_data if extraction else {}
            blocks = extracted_data.get('semester_blocks', [])
            if blocks and len(blocks) > 0:
                summary = {
                    'document_type': existing.document_type,
                    'is_multi_semester': extracted_data.get('is_multi_semester', len(blocks) > 1),
                    'semester_blocks': blocks,
                    'total_semesters_detected': len(blocks),
                    'semester': existing.detected_semester,
                    'exam_type': existing.detected_exam_type,
                    'subjects_count': len(extracted_data.get('subjects', [])),
                    'subjects': extracted_data.get('subjects', []),
                    'student_match': existing.student_match_verified,
                    'student_name': existing.extracted_student_name,
                    'registration_number': existing.extracted_reg_no,
                }
                return Response({
                    'message': 'This grade sheet has already been uploaded and parsed.',
                    'gradesheet': GradeSheetSerializer(existing).data,
                    'status': existing.upload_status,
                    'extracted_summary': summary,
                    'is_duplicate': True
                }, status=status.HTTP_200_OK)
            else:
                # Reprocess existing
                try:
                    result = IngestionService.process_gradesheet(
                        gradesheet=existing,
                        custom_semester=serializer.validated_data.get('custom_semester'),
                        custom_exam_type=serializer.validated_data.get('custom_exam_type')
                    )
                    return Response({
                        'message': 'Grade sheet parsed successfully.',
                        'gradesheet': GradeSheetSerializer(existing).data,
                        'status': existing.upload_status,
                        'extracted_summary': result,
                        'is_duplicate': False
                    }, status=status.HTTP_200_OK)
                except Exception as e:
                    return Response({'error': str(e)}, status=status.HTTP_400_BAD_REQUEST)

        # Create GradeSheet
        gradesheet = GradeSheet.objects.create(
            student=student_profile,
            original_filename=uploaded_file.name,
            file=uploaded_file,
            file_hash=file_hash,
            upload_status='PROCESSING'
        )

        # Create Processing Job
        job = ProcessingJob.objects.create(
            student=student_profile,
            gradesheet=gradesheet,
            status='PROCESSING',
            stage='PREPROCESSING',
            message='Analyzing document structure...'
        )

        # Run Document Intelligence Pipeline
        try:
            result = IngestionService.process_gradesheet(
                gradesheet=gradesheet,
                job=job,
                custom_semester=serializer.validated_data.get('custom_semester'),
                custom_exam_type=serializer.validated_data.get('custom_exam_type')
            )
            return Response({
                'gradesheet': GradeSheetSerializer(gradesheet).data,
                'job_id': str(job.id),
                'status': gradesheet.upload_status,
                'message': job.message,
                'extracted_summary': result
            }, status=status.HTTP_201_CREATED)
        except Exception as e:
            job.status = 'FAILED'
            job.stage = 'ERROR'
            job.message = str(e)
            job.save()
            gradesheet.upload_status = 'REJECTED'
            gradesheet.save()
            return Response({'error': str(e), 'job_id': str(job.id)}, status=status.HTTP_400_BAD_REQUEST)

class GradeSheetListView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        profile = get_active_student_profile(request)
        sheets = GradeSheet.objects.filter(student=profile)
        serializer = GradeSheetSerializer(sheets, many=True)
        return Response(serializer.data)

class GradeSheetDetailView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request, pk):
        profile = get_active_student_profile(request)
        try:
            sheet = GradeSheet.objects.get(pk=pk, student=profile)
            return Response(GradeSheetSerializer(sheet).data)
        except GradeSheet.DoesNotExist:
            return Response({'error': 'Grade sheet not found'}, status=status.HTTP_404_NOT_FOUND)

    def delete(self, request, pk):
        profile = get_active_student_profile(request)
        try:
            sheet = GradeSheet.objects.get(pk=pk, student=profile)
            sheet.delete()
            return Response({'message': 'Grade sheet deleted successfully.'}, status=status.HTTP_204_NO_CONTENT)
        except GradeSheet.DoesNotExist:
            return Response({'error': 'Grade sheet not found'}, status=status.HTTP_404_NOT_FOUND)

class GradeSheetVerifyView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request, pk):
        profile = get_active_student_profile(request)
        try:
            sheet = GradeSheet.objects.get(pk=pk, student=profile)
        except GradeSheet.DoesNotExist:
            return Response({'error': 'Grade sheet not found'}, status=status.HTTP_404_NOT_FOUND)

        payload = request.data
        semester_blocks = payload.get('semester_blocks')

        from services.matching.reconciler import AttemptReconciler

        if semester_blocks and isinstance(semester_blocks, list) and len(semester_blocks) > 0:
            reconciled_attempts = []
            for block in semester_blocks:
                sem_num = int(block.get('semester') or 1)
                exam_type = block.get('exam_type') or 'REGULAR'
                subs = block.get('subjects', [])
                if subs:
                    rec = AttemptReconciler.commit_verified_attempt(
                        gradesheet=sheet,
                        semester_num=sem_num,
                        exam_type=exam_type,
                        subjects_data=subs
                    )
                    reconciled_attempts.append(rec)

            sheet.upload_status = 'VERIFIED'
            sheet.save()

            from services.calculation.engine import CalculationEngine
            summary = CalculationEngine.calculate_academic_summary(profile)

            return Response({
                'message': f"Verified {len(reconciled_attempts)} semester attempt(s) successfully.",
                'attempts_processed': len(reconciled_attempts),
                'cgpa': float(summary.cgpa),
                'reconciled': reconciled_attempts
            }, status=status.HTTP_200_OK)
        else:
            verified_subjects = payload.get('subjects', [])
            verified_semester = payload.get('semester', sheet.detected_semester)
            verified_exam_type = payload.get('exam_type', sheet.detected_exam_type)

            reconciled = AttemptReconciler.commit_verified_attempt(
                gradesheet=sheet,
                semester_num=int(verified_semester or 1),
                exam_type=verified_exam_type or 'REGULAR',
                subjects_data=verified_subjects
            )

            sheet.upload_status = 'VERIFIED'
            sheet.save()

            return Response({
                'message': 'Attempt verified and academic standing recalculated.',
                'semester': reconciled['semester_id'],
                'sgpa': reconciled['sgpa'],
                'cgpa': reconciled['cgpa']
            }, status=status.HTTP_200_OK)
