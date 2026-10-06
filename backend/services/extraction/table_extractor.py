import re

class TableExtractor:
    """Extracts subjects, credits, and grades from parsed document text."""

    VALID_GRADES = {
        'EX': 10.0,
        'A': 9.0,
        'B': 8.0,
        'C': 7.0,
        'D': 6.0,
        'P': 5.0,
        'M': 4.0,
        'F': 0.0,
    }

    GRADE_ALIASES = {
        'EX': 'EX', 'EXCELLENT': 'EX', 'E-X': 'EX', 'E X': 'EX',
        'A': 'A', 'B': 'B', 'C': 'C', 'D': 'D',
        'P': 'P', 'PASS': 'P',
        'M': 'M',
        'F': 'F', 'FAIL': 'F',
    }

    @classmethod
    def normalize_grade(cls, raw_grade):
        if not raw_grade:
            return 'UNKNOWN_GRADE', 0.0, False, True

        cleaned = re.sub(r'[^A-Za-z\- ]', '', str(raw_grade)).strip().upper()
        # Clean extra spaces
        cleaned = re.sub(r'\s+', ' ', cleaned)

        norm = cls.GRADE_ALIASES.get(cleaned)
        if norm and norm in cls.VALID_GRADES:
            gp = cls.VALID_GRADES[norm]
            is_pass = norm != 'F'
            return norm, gp, is_pass, False

        return 'UNKNOWN_GRADE', 0.0, False, True

    @classmethod
    def extract_subjects_from_text(cls, text):
        """
        Parses structured lines matching:
        [Code] [Subject Name...] [Credits] [Grade]
        or tabular format.
        """
        subjects = []
        lines = [line.strip() for line in text.split('\n') if line.strip()]

        # Pattern: Code (e.g. CS301, 18CS301, MATH-101) + Subject Title + Credits (float/int) + Grade
        # Also handles variations where credits and grades appear in different order
        row_pattern = re.compile(
            r'^(?P<code>[A-Z0-9]{2,10}(?:-[A-Z0-9]+)?)?\s+'
            r'(?P<title>[A-Za-z0-9\s\(\)&,\.\-\/]{4,50})\s+'
            r'(?P<credits>\d+(?:\.\d+)?)\s+'
            r'(?P<grade>EX|Ex|A|B|C|D|P|M|F|[A-Za-z]{1,3})\b',
            re.IGNORECASE
        )

        # Fallback pattern without subject code
        fallback_pattern = re.compile(
            r'^(?P<title>[A-Za-z\s\(\)&,\.\-\/]{5,50})\s+'
            r'(?P<credits>\d+(?:\.\d+)?)\s+'
            r'(?P<grade>EX|Ex|A|B|C|D|P|M|F|[A-Za-z]{1,3})\b',
            re.IGNORECASE
        )

        for line in lines:
            # Skip typical headers
            upper_line = line.upper()
            if any(h in upper_line for h in ["SUBJECT", "COURSE", "CREDIT", "GRADE POINT", "SL NO", "PAGE"]):
                continue

            match = row_pattern.search(line)
            if not match:
                match = fallback_pattern.search(line)

            if match:
                data = match.groupdict()
                code = (data.get('code') or '').strip().upper()
                title = data['title'].strip()
                try:
                    credits = float(data['credits'])
                except ValueError:
                    credits = 3.0

                raw_grade = data['grade'].strip()
                norm_grade, grade_point, is_pass, needs_review = cls.normalize_grade(raw_grade)

                # Confidence scoring
                confidence = 0.95
                if needs_review:
                    confidence = 0.50
                elif not code:
                    confidence = 0.85

                subjects.append({
                    'code': code,
                    'name': title,
                    'credits': credits,
                    'raw_grade': raw_grade,
                    'normalized_grade': norm_grade,
                    'grade_point': grade_point,
                    'is_pass': is_pass,
                    'confidence': confidence,
                    'needs_review': needs_review or confidence < 0.70
                })

        return subjects
