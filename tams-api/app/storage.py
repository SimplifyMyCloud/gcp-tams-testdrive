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

    def generate_upload_url(
        self, flow_id: str, segment_id: str, content_type: str = "application/octet-stream"
    ) -> tuple[str, str]:
        """
        Generate signed URL for uploading a segment directly to GCS.

        Args:
            flow_id: Flow ID
            segment_id: Segment ID
            content_type: MIME type for the upload

        Returns:
            Tuple of (signed_url, gcs_uri)
        """
        import datetime
        from google.auth import compute_engine
        from google.auth.transport import requests as auth_requests
        from google.auth import iam
        from google.auth import impersonated_credentials

        blob_name = f"flows/{flow_id}/segments/{segment_id}"
        blob = self.bucket.blob(blob_name)

        # Get the service account email from the metadata server
        import requests
        credentials = self.client._credentials
        try:
            r = requests.get(
                "http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email",
                headers={"Metadata-Flavor": "Google"},
                timeout=1
            )
            service_account_email = r.text.strip()
        except Exception as e:
            raise ValueError(f"Could not determine service account email: {e}")

        # Create an IAM signer using the current credentials
        # This makes API calls to the IAM service to sign the URL
        auth_request = auth_requests.Request()
        signing_credentials = impersonated_credentials.Credentials(
            source_credentials=credentials,
            target_principal=service_account_email,
            target_scopes=['https://www.googleapis.com/auth/devstorage.read_write'],
            lifetime=3600
        )

        # Use IAM-based signing (doesn't require private key)
        url = blob.generate_signed_url(
            version="v4",
            expiration=datetime.timedelta(hours=1),
            method="PUT",
            content_type=content_type,
            credentials=signing_credentials,
        )

        gcs_uri = f"gs://{self.bucket_name}/{blob_name}"

        return url, gcs_uri

    def get_segment_url(self, flow_id: str, segment_id: str) -> str:
        """
        Get public URL for segment access.

        Since the bucket is public for demo/POC, we return a direct public URL.

        Args:
            flow_id: Flow ID
            segment_id: Segment ID

        Returns:
            Public GCS URL
        """
        blob_name = f"flows/{flow_id}/segments/{segment_id}"

        # Return direct public URL for the bucket
        # Format: https://storage.googleapis.com/bucket-name/path/to/file
        return f"https://storage.googleapis.com/{self.bucket_name}/{blob_name}"

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
