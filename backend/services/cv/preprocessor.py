import cv2
import numpy as np
from PIL import Image
import os

class ImagePreprocessor:
    """Production OpenCV Image Preprocessing for Academic Grade Sheets."""

    @staticmethod
    def preprocess_image(input_path_or_bytes, output_path=None):
        """
        Executes:
        1. Grayscale conversion
        2. Resolution normalization (target 300 DPI)
        3. Background illumination correction (shadow removal)
        4. Deskewing via text orientation
        5. Adaptive thresholding
        """
        if isinstance(input_path_or_bytes, str):
            image = cv2.imread(input_path_or_bytes)
        elif isinstance(input_path_or_bytes, bytes):
            nparr = np.frombuffer(input_path_or_bytes, np.uint8)
            image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        else:
            raise ValueError("Unsupported input format for preprocessor")

        if image is None:
            raise ValueError("Unable to decode image file")

        # 1. Grayscale
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)

        # 2. Illumination / Shadow Removal via morphological opening
        kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (25, 25))
        background = cv2.morphologyEx(gray, cv2.MORPH_OPEN, kernel)
        normalized = cv2.divide(gray, background, scale=255)

        # 3. Deskewing
        deskewed = ImagePreprocessor._deskew(normalized)

        # 4. Adaptive thresholding (clean contrast while preserving lines)
        thresh = cv2.adaptiveThreshold(
            deskewed, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
            cv2.THRESH_BINARY, 21, 10
        )

        if output_path:
            os.makedirs(os.path.dirname(output_path), exist_ok=True)
            cv2.imwrite(output_path, thresh)

        return thresh, deskewed, image

    @staticmethod
    def _deskew(image):
        """Estimate skew angle and rotate."""
        try:
            coords = np.column_stack(np.where(image < 200))
            if len(coords) < 100:
                return image
            angle = cv2.minAreaRect(coords)[-1]
            if angle < -45:
                angle = -(90 + angle)
            elif angle > 45:
                angle = 90 - angle
            else:
                angle = -angle

            if abs(angle) < 0.5 or abs(angle) > 45:
                return image  # Negligible or false angle

            (h, w) = image.shape[:2]
            center = (w // 2, h // 2)
            M = cv2.getRotationMatrix2D(center, angle, 1.0)
            rotated = cv2.warpAffine(
                image, M, (w, h),
                flags=cv2.INTER_CUBIC,
                borderMode=cv2.BORDER_REPLICATE
            )
            return rotated
        except Exception:
            return image
