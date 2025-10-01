"""Google Cloud Storage operations for TAMS media."""
from google.cloud import storage
from typing import Optional
import uuid
from .config import config


class StorageManager:
    """Manage media storage in GCS."""

    def __init__(self):
        """Initialize storage client."""
        self.client = storage.Client()
        self.bucket_name = config.GCS_BUCKET
        self.bucket = self.client.bucket(self.bucket_name)

    def upload_segment(
        self, file_data: bytes, flow_id: str, segment_id: str, content_type: str = "application/octet-stream"
    ) -> str:
        """
        Upload a segment to GCS.

        Args:
            file_data: Binary data to upload
            flow_id: Flow ID
            segment_id: Segment ID
            content_type: MIME type

        Returns:
            GCS URI for the uploaded file
        """
        blob_name = f"flows/{flow_id}/segments/{segment_id}"
        blob = self.bucket.blob(blob_name)
        blob.upload_from_string(file_data, content_type=content_type)

        return f"gs://{self.bucket_name}/{blob_name}"

    def get_segment_url(self, flow_id: str, segment_id: str) -> str:
        """
        Get signed URL for segment access.

        Args:
            flow_id: Flow ID
            segment_id: Segment ID

        Returns:
            Signed URL valid for 1 hour
        """
        blob_name = f"flows/{flow_id}/segments/{segment_id}"
        blob = self.bucket.blob(blob_name)

        url = blob.generate_signed_url(
            version="v4",
            expiration=3600,  # 1 hour
            method="GET",
        )

        return url

    def delete_segment(self, flow_id: str, segment_id: str) -> bool:
        """
        Delete a segment from GCS.

        Args:
            flow_id: Flow ID
            segment_id: Segment ID

        Returns:
            True if deleted successfully
        """
        blob_name = f"flows/{flow_id}/segments/{segment_id}"
        blob = self.bucket.blob(blob_name)

        try:
            blob.delete()
            return True
        except Exception:
            return False

    def get_segment_size(self, flow_id: str, segment_id: str) -> Optional[int]:
        """
        Get segment size in bytes.

        Args:
            flow_id: Flow ID
            segment_id: Segment ID

        Returns:
            Size in bytes or None
        """
        blob_name = f"flows/{flow_id}/segments/{segment_id}"
        blob = self.bucket.blob(blob_name)

        blob.reload()
        return blob.size


# Global storage manager instance
storage_manager = StorageManager()
