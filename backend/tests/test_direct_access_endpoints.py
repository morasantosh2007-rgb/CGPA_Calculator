from django.test import TestCase, Client
from apps.grading.models import GradingSystem, GradeRule, CalculationPolicy

class DirectAccessEndpointsTestCase(TestCase):
    def setUp(self):
        self.client = Client()
        system = GradingSystem.objects.create(name="Standard Scale", code="DEFAULT_EX_F", is_default=True)
        rules = [
            ('EX', 10.0, True), ('A', 9.0, True), ('B', 8.0, True),
            ('C', 7.0, True), ('D', 6.0, True), ('P', 5.0, True),
            ('M', 4.0, True), ('F', 0.0, False)
        ]
        for g, gp, p in rules:
            GradeRule.objects.create(grading_system=system, grade=g, grade_point=gp, is_pass=p)

        CalculationPolicy.objects.create(
            code="POLICY_A_LATEST_PASS",
            name="Policy A",
            is_default=True
        )

    def test_unauthenticated_summary_endpoint(self):
        """GET /api/calculations/summary/ must return 200 OK without login."""
        response = self.client.get('/api/calculations/summary/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('cgpa', response.json())
        self.assertIn('total_credits_completed', response.json())

    def test_unauthenticated_progression_endpoint(self):
        """GET /api/analytics/progression/ must return 200 OK without login."""
        response = self.client.get('/api/analytics/progression/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('progression', response.json())

    def test_unauthenticated_semesters_endpoint(self):
        """GET /api/semesters/ must return 200 OK without login."""
        response = self.client.get('/api/semesters/')
        self.assertEqual(response.status_code, 200)

    def test_unauthenticated_distribution_endpoint(self):
        """GET /api/analytics/distribution/ must return 200 OK without login."""
        response = self.client.get('/api/analytics/distribution/')
        self.assertEqual(response.status_code, 200)
        self.assertIn('EX', response.json())
