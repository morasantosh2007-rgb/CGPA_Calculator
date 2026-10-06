import re
from rapidfuzz import fuzz

class SubjectMatcher:
    """Matches subject attempts across different grade sheets and semesters."""

    @staticmethod
    def normalize_code(code):
        if not code:
            return ""
        return re.sub(r'[^A-Z0-9]', '', code.upper())

    @staticmethod
    def normalize_title(title):
        if not title:
            return ""
        # Remove common academic noise words
        t = re.sub(r'[^a-zA-Z0-9\s]', ' ', title.lower())
        stopwords = {'and', 'the', 'of', 'in', 'to', 'for', 'theory'}
        tokens = [w for w in t.split() if w not in stopwords]
        return " ".join(tokens)

    @classmethod
    def is_match(cls, code1, title1, code2, title2, threshold=85):
        norm_c1 = cls.normalize_code(code1)
        norm_c2 = cls.normalize_code(code2)

        # 1. Primary Match: Subject Code
        if norm_c1 and norm_c2:
            return norm_c1 == norm_c2

        # Disambiguation: Lab vs Theory
        t1_upper = title1.upper()
        t2_upper = title2.upper()
        is_lab1 = "LAB" in t1_upper or "PRACTICAL" in t1_upper
        is_lab2 = "LAB" in t2_upper or "PRACTICAL" in t2_upper
        if is_lab1 != is_lab2:
            return False

        # 2. Secondary Match: Title Fuzzy Similarity
        t1_norm = cls.normalize_title(title1)
        t2_norm = cls.normalize_title(title2)
        score = fuzz.token_sort_ratio(t1_norm, t2_norm)
        return score >= threshold
