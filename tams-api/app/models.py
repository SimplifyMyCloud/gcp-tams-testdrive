"""Pydantic models for API requests/responses."""
from pydantic import BaseModel, Field
from typing import Optional, Dict, Any
from datetime import datetime


class SourceCreate(BaseModel):
    """Source creation request."""

    id: str
    label: str
    description: Optional[str] = None
    tags: Optional[Dict[str, Any]] = Field(default_factory=dict)


class SourceResponse(BaseModel):
    """Source response."""

    id: str
    label: str
    description: Optional[str]
    tags: Dict[str, Any]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class FlowCreate(BaseModel):
    """Flow creation request."""

    id: str
    source_id: str
    label: str
    description: Optional[str] = None
    format: str
    codec: Optional[str] = None
    tags: Optional[Dict[str, Any]] = Field(default_factory=dict)


class FlowResponse(BaseModel):
    """Flow response."""

    id: str
    source_id: str
    label: str
    description: Optional[str]
    format: str
    codec: Optional[str]
    tags: Dict[str, Any]
    timerange_start: Optional[str]
    timerange_end: Optional[str]
    created_at: datetime
    updated_at: datetime

    class Config:
        from_attributes = True


class SegmentCreate(BaseModel):
    """Segment creation request."""

    id: str
    flow_id: str
    timerange_start: str
    timerange_end: str
    duration: Optional[float] = None
    tags: Optional[Dict[str, Any]] = Field(default_factory=dict)


class SegmentResponse(BaseModel):
    """Segment response."""

    id: str
    flow_id: str
    timerange_start: str
    timerange_end: str
    duration: Optional[float]
    storage_uri: str
    size_bytes: Optional[int]
    tags: Dict[str, Any]
    created_at: datetime

    class Config:
        from_attributes = True


class HealthResponse(BaseModel):
    """Health check response."""

    status: str
    version: str
    timestamp: datetime
