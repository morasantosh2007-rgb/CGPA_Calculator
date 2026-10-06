from django.http import HttpResponse, JsonResponse
from rest_framework.views import APIView
from rest_framework import permissions
from services.reports.pdf_generator import PDFReportGenerator
from apps.students.utils import get_active_student_profile

class ExportTranscriptPDFView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        profile = get_active_student_profile(request)
        pdf_bytes = PDFReportGenerator.generate_transcript_pdf(profile)
        
        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        filename = f"GradeLens_Transcript_{profile.registration_number or 'Student'}.pdf"
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response

class ExportAuditJSONView(APIView):
    permission_classes = [permissions.AllowAny]

    def get(self, request):
        profile = get_active_student_profile(request)
        audit_data = PDFReportGenerator.generate_audit_json(profile)
        return JsonResponse(audit_data, safe=False)
