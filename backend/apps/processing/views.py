from rest_framework import generics, permissions
from .models import ProcessingJob
from .serializers import ProcessingJobSerializer

class ProcessingJobDetailView(generics.RetrieveAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProcessingJobSerializer

    def get_queryset(self):
        return ProcessingJob.objects.filter(student__user=self.request.user)

class ProcessingJobListView(generics.ListAPIView):
    permission_classes = [permissions.IsAuthenticated]
    serializer_class = ProcessingJobSerializer

    def get_queryset(self):
        return ProcessingJob.objects.filter(student__user=self.request.user)
