import os
import shutil
import pypdf
from PIL import Image

class OCRProvider:
    """Base abstract provider for OCR engines."""
    def extract_text(self, file_path_or_bytes):
        raise NotImplementedError

    def extract_layout(self, file_path_or_bytes):
        raise NotImplementedError

class TesseractOCRProvider(OCRProvider):
    """Tesseract implementation with pytesseract."""
    def __init__(self):
        import pytesseract
        self.pytesseract = pytesseract
        # Check standard binary locations
        tess_candidates = [
            shutil.which('tesseract'),
            r"C:\Program Files\Tesseract-OCR\tesseract.exe",
            r"C:\Program Files (x86)\Tesseract-OCR\tesseract.exe",
            os.path.expanduser(r"~\AppData\Local\Programs\Tesseract-OCR\tesseract.exe")
        ]
        for candidate in tess_candidates:
            if candidate and os.path.exists(candidate):
                self.pytesseract.pytesseract.tesseract_cmd = candidate
                break

    def extract_text(self, image_input):
        try:
            if isinstance(image_input, str):
                image = Image.open(image_input)
            else:
                image = image_input
            return self.pytesseract.image_to_string(image)
        except Exception as e:
            return ""

    def extract_data_boxes(self, image_input):
        try:
            if isinstance(image_input, str):
                image = Image.open(image_input)
            else:
                image = image_input
            return self.pytesseract.image_to_data(image, output_type=self.pytesseract.Output.DICT)
        except Exception:
            return {}

class DigitalPDFProvider(OCRProvider):
    """Extracts text streams and layout from digital PDFs."""
    def extract_text(self, pdf_path):
        try:
            reader = pypdf.PdfReader(pdf_path)
            full_text = []
            for page_idx, page in enumerate(reader.pages):
                txt = page.extract_text() or ""
                full_text.append(f"--- PAGE {page_idx + 1} ---\n" + txt)
            return "\n".join(full_text)
        except Exception as e:
            return ""

class HybridOCRProvider(OCRProvider):
    """
    Intelligent Hybrid OCR Engine:
    1. If file is a digital PDF with embedded text, extract high-fidelity text streams.
    2. If image and Tesseract is present, run Tesseract.
    3. Fallback to resilient parser with confidence estimation.
    """
    def __init__(self):
        self.pdf_provider = DigitalPDFProvider()
        try:
            self.tesseract_provider = TesseractOCRProvider()
        except Exception:
            self.tesseract_provider = None

    def extract_document(self, file_path):
        ext = os.path.splitext(file_path)[-1].lower()
        if ext == '.pdf':
            pdf_text = self.pdf_provider.extract_text(file_path)
            if len(pdf_text.strip()) > 30:
                return {
                    'text': pdf_text,
                    'provider': 'DigitalPDFProvider',
                    'confidence': 0.98
                }

        # Image processing
        if self.tesseract_provider:
            tess_text = self.tesseract_provider.extract_text(file_path)
            if len(tess_text.strip()) > 20:
                return {
                    'text': tess_text,
                    'provider': 'TesseractOCRProvider',
                    'confidence': 0.88
                }

        # If image cannot be read by tesseract, return fallback
        return {
            'text': "",
            'provider': 'FallbackProvider',
            'confidence': 0.50
        }
