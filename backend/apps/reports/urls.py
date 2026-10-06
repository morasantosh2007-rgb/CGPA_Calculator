from django.urls import path
from .views import ExportTranscriptPDFView, ExportAuditJSONView

urlpatterns = [
    path('transcript-pdf/', ExportTranscriptPDFView.as_view(), name='export_transcript_pdf'),
    path('audit-json/', ExportAuditJSONView.as_view(), name='export_audit_json'),
]
