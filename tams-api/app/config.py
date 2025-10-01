"""Configuration management for TAMS API."""
import os
from typing import Optional


class Config:
    """Application configuration."""

    # Database
    DB_HOST: str = os.getenv("DB_HOST", "localhost")
    DB_PORT: int = int(os.getenv("DB_PORT", "5432"))
    DB_NAME: str = os.getenv("DB_NAME", "tams")
    DB_USER: str = os.getenv("DB_USER", "tams")
    DB_PASSWORD: str = os.getenv("DB_PASSWORD", "")
    INSTANCE_CONNECTION_NAME: Optional[str] = os.getenv("INSTANCE_CONNECTION_NAME")

    # Storage
    GCS_BUCKET: str = os.getenv("GCS_BUCKET", "")

    # API
    API_VERSION: str = "v1.0"
    API_TITLE: str = "TAMS API"
    API_DESCRIPTION: str = "Time Addressable Media Store API"

    # Server
    PORT: int = int(os.getenv("PORT", "8080"))
    HOST: str = os.getenv("HOST", "0.0.0.0")

    @property
    def database_url(self) -> str:
        """Get database URL."""
        if self.INSTANCE_CONNECTION_NAME:
            # Cloud SQL connection
            return (
                f"postgresql://{self.DB_USER}:{self.DB_PASSWORD}"
                f"@/{self.DB_NAME}?host=/cloudsql/{self.INSTANCE_CONNECTION_NAME}"
            )
        else:
            # Standard connection
            return (
                f"postgresql://{self.DB_USER}:{self.DB_PASSWORD}"
                f"@{self.DB_HOST}:{self.DB_PORT}/{self.DB_NAME}"
            )


config = Config()
