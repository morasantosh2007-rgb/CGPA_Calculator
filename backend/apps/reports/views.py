from django.http import HttpResponse, JsonResponse
from rest_framework.views import APIView
from rest_framework import permissions
from services.reports.pdf_generator import PDFReportGenerator

class ExportTranscriptPDFView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile = request.user.student_profile
        pdf_bytes = PDFReportGenerator.generate_transcript_pdf(profile)
        
        response = HttpResponse(pdf_bytes, content_type='application/pdf')
        filename = f"GradeLens_Transcript_{profile.registration_number or 'Student'}.pdf"
        response['Content-Disposition'] = f'attachment; filename="{filename}"'
        return response

class ExportAuditJSONView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        profile = request.user.student_profile
        audit_data = PDFReportGenerator.generate_audit_json(profile)
        return JsonResponse(audit_data, safe=False)
