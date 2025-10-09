"""TAMS API - Main application."""
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
import logging
import json

from google.cloud import videointelligence

from .config import config
from .database import get_db, init_db, Source, Flow, Segment
from .models import (
    SourceCreate,
    SourceResponse,
    FlowCreate,
    FlowResponse,
    SegmentCreate,
    SegmentResponse,
    UploadUrlRequest,
    UploadUrlResponse,
    SegmentCreateDirect,
    HealthResponse,
)
from .storage import storage_manager

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title=config.API_TITLE,
    description=config.API_DESCRIPTION,
    version=config.API_VERSION,
)

# Add CORS middleware to allow frontend to call API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all origins for demo/POC
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods
    allow_headers=["*"],  # Allow all headers
)


@app.on_event("startup")
async def startup_event():
    """Initialize database on startup."""
    logger.info("Initializing database...")
    init_db()
    logger.info("Database initialized successfully")


@app.get("/", response_model=HealthResponse)
async def root():
    """Root endpoint - health check."""
    return HealthResponse(
        status="healthy",
        version=config.API_VERSION,
        timestamp=datetime.utcnow(),
    )


@app.get("/health", response_model=HealthResponse)
async def health():
    """Health check endpoint."""
    return HealthResponse(
        status="healthy",
        version=config.API_VERSION,
        timestamp=datetime.utcnow(),
    )


# ============================================================================
# SOURCE ENDPOINTS
# ============================================================================


@app.post("/sources", response_model=SourceResponse, status_code=201)
async def create_source(source: SourceCreate, db: Session = Depends(get_db)):
    """Create a new source."""
    # Check if source already exists
    existing = db.query(Source).filter(Source.id == source.id).first()
    if existing:
        raise HTTPException(status_code=409, detail="Source already exists")

    db_source = Source(**source.model_dump())
    db.add(db_source)
    db.commit()
    db.refresh(db_source)

    logger.info(f"Created source: {source.id}")
    return db_source


@app.get("/sources", response_model=List[SourceResponse])
async def list_sources(db: Session = Depends(get_db)):
    """List all sources."""
    sources = db.query(Source).all()
    return sources


@app.get("/sources/{source_id}", response_model=SourceResponse)
async def get_source(source_id: str, db: Session = Depends(get_db)):
    """Get a specific source."""
    source = db.query(Source).filter(Source.id == source_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Source not found")
    return source


@app.delete("/sources/{source_id}", status_code=204)
async def delete_source(source_id: str, db: Session = Depends(get_db)):
    """Delete a source."""
    source = db.query(Source).filter(Source.id == source_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Source not found")

    db.delete(source)
    db.commit()
    logger.info(f"Deleted source: {source_id}")


# ============================================================================
# FLOW ENDPOINTS
# ============================================================================


@app.post("/flows", response_model=FlowResponse, status_code=201)
async def create_flow(flow: FlowCreate, db: Session = Depends(get_db)):
    """Create a new flow."""
    # Check if source exists
    source = db.query(Source).filter(Source.id == flow.source_id).first()
    if not source:
        raise HTTPException(status_code=404, detail="Source not found")

    # Check if flow already exists
    existing = db.query(Flow).filter(Flow.id == flow.id).first()
    if existing:
        raise HTTPException(status_code=409, detail="Flow already exists")

    db_flow = Flow(**flow.model_dump())
    db.add(db_flow)
    db.commit()
    db.refresh(db_flow)

    logger.info(f"Created flow: {flow.id}")
    return db_flow


@app.get("/flows", response_model=List[FlowResponse])
async def list_flows(source_id: str = None, db: Session = Depends(get_db)):
    """List all flows, optionally filtered by source."""
    query = db.query(Flow)
    if source_id:
        query = query.filter(Flow.source_id == source_id)
    flows = query.all()
    return flows


@app.get("/flows/{flow_id}", response_model=FlowResponse)
async def get_flow(flow_id: str, db: Session = Depends(get_db)):
    """Get a specific flow."""
    flow = db.query(Flow).filter(Flow.id == flow_id).first()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")
    return flow


@app.delete("/flows/{flow_id}", status_code=204)
async def delete_flow(flow_id: str, db: Session = Depends(get_db)):
    """Delete a flow."""
    flow = db.query(Flow).filter(Flow.id == flow_id).first()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")

    db.delete(flow)
    db.commit()
    logger.info(f"Deleted flow: {flow_id}")


# ============================================================================
# SEGMENT ENDPOINTS
# ============================================================================


@app.post("/segments/upload-url", response_model=UploadUrlResponse)
async def get_upload_url(request: UploadUrlRequest, db: Session = Depends(get_db)):
    """Get signed URL for direct upload to GCS."""
    # Check if flow exists
    flow = db.query(Flow).filter(Flow.id == request.flow_id).first()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")

    # Generate signed URL
    upload_url, gcs_uri = storage_manager.generate_upload_url(
        request.flow_id, request.segment_id, request.content_type
    )

    logger.info(f"Generated upload URL for segment: {request.segment_id}")

    return UploadUrlResponse(
        upload_url=upload_url,
        gcs_uri=gcs_uri,
        expires_in=3600,
    )


@app.post("/segments/direct", response_model=SegmentResponse, status_code=201)
async def create_segment_direct(segment: SegmentCreateDirect, db: Session = Depends(get_db)):
    """Create a segment with pre-uploaded file (direct GCS upload)."""
    # Check if flow exists
    flow = db.query(Flow).filter(Flow.id == segment.flow_id).first()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")

    # Check if segment already exists
    existing = db.query(Segment).filter(Segment.id == segment.id).first()
    if existing:
        raise HTTPException(status_code=409, detail="Segment already exists")

    # Get file size from GCS if not provided
    size_bytes = segment.size_bytes
    if size_bytes is None:
        size_bytes = storage_manager.get_segment_size(segment.flow_id, segment.id)

    # Create segment in database
    db_segment = Segment(
        id=segment.id,
        flow_id=segment.flow_id,
        timerange_start=segment.timerange_start,
        timerange_end=segment.timerange_end,
        duration=segment.duration,
        storage_uri=segment.storage_uri,
        size_bytes=size_bytes,
        tags=segment.tags,
    )
    db.add(db_segment)
    db.commit()
    db.refresh(db_segment)

    logger.info(f"Created segment (direct upload): {segment.id}")
    return db_segment


@app.post("/segments", response_model=SegmentResponse, status_code=201)
async def create_segment(
    segment: SegmentCreate,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Create a new segment with media upload (legacy method)."""
    # Check if flow exists
    flow = db.query(Flow).filter(Flow.id == segment.flow_id).first()
    if not flow:
        raise HTTPException(status_code=404, detail="Flow not found")

    # Check if segment already exists
    existing = db.query(Segment).filter(Segment.id == segment.id).first()
    if existing:
        raise HTTPException(status_code=409, detail="Segment already exists")

    # Upload file to GCS
    file_data = await file.read()
    storage_uri = storage_manager.upload_segment(
        file_data, segment.flow_id, segment.id, file.content_type or "application/octet-stream"
    )

    # Get file size
    size_bytes = len(file_data)

    # Create segment in database
    db_segment = Segment(
        **segment.model_dump(),
        storage_uri=storage_uri,
        size_bytes=size_bytes,
    )
    db.add(db_segment)
    db.commit()
    db.refresh(db_segment)

    logger.info(f"Created segment: {segment.id}")
    return db_segment


@app.get("/segments", response_model=List[SegmentResponse])
async def list_segments(flow_id: str = None, db: Session = Depends(get_db)):
    """List all segments, optionally filtered by flow."""
    query = db.query(Segment)
    if flow_id:
        query = query.filter(Segment.flow_id == flow_id)
    segments = query.all()
    return segments


@app.get("/segments/{segment_id}", response_model=SegmentResponse)
async def get_segment(segment_id: str, db: Session = Depends(get_db)):
    """Get a specific segment."""
    segment = db.query(Segment).filter(Segment.id == segment_id).first()
    if not segment:
        raise HTTPException(status_code=404, detail="Segment not found")
    return segment


@app.get("/segments/{segment_id}/download")
async def download_segment(segment_id: str, db: Session = Depends(get_db)):
    """Get download URL for a segment."""
    segment = db.query(Segment).filter(Segment.id == segment_id).first()
    if not segment:
        raise HTTPException(status_code=404, detail="Segment not found")

    # Get public URL (bucket is public for demo/POC)
    url = storage_manager.get_segment_url(segment.flow_id, segment_id)

    # Note: Public URLs don't expire, but keeping expires_in for API consistency
    return JSONResponse(content={"url": url, "expires_in": 3600})


@app.delete("/segments/{segment_id}", status_code=204)
async def delete_segment(segment_id: str, db: Session = Depends(get_db)):
    """Delete a segment."""
    segment = db.query(Segment).filter(Segment.id == segment_id).first()
    if not segment:
        raise HTTPException(status_code=404, detail="Segment not found")

    # Delete from storage
    storage_manager.delete_segment(segment.flow_id, segment_id)

    # Delete from database
    db.delete(segment)
    db.commit()
    logger.info(f"Deleted segment: {segment_id}")


@app.post("/segments/{segment_id}/analyze", response_model=SegmentResponse)
async def analyze_segment(segment_id: str, db: Session = Depends(get_db)):
    """Analyze segment video using Video Intelligence API for logo detection."""
    segment = db.query(Segment).filter(Segment.id == segment_id).first()
    if not segment:
        raise HTTPException(status_code=404, detail="Segment not found")

    logger.info(f"Starting video analysis for segment: {segment_id}")

    try:
        # Initialize Video Intelligence client
        video_client = videointelligence.VideoIntelligenceServiceClient()

        # Configure the request for logo detection
        features = [videointelligence.Feature.LOGO_RECOGNITION]

        # Start the analysis operation
        logger.info(f"Calling Video Intelligence API for: {segment.storage_uri}")
        operation = video_client.annotate_video(
            request={
                "features": features,
                "input_uri": segment.storage_uri,
            }
        )

        logger.info("Waiting for Video Intelligence API to complete...")
        result = operation.result(timeout=300)  # 5 minute timeout

        # Process the results
        logos_data = []

        # Get the first annotation result
        annotation_result = result.annotation_results[0]

        # Process logo recognition annotations
        for logo_annotation in annotation_result.logo_recognition_annotations:
            logo_entity = logo_annotation.entity

            # Collect time segments where logo appears
            segments_list = []
            for track in logo_annotation.tracks:
                # Get start and end times
                start_time = track.segment.start_time_offset.total_seconds()
                end_time = track.segment.end_time_offset.total_seconds()

                # Get confidence from track (if available, otherwise use 0.5 as default)
                confidence = track.confidence if hasattr(track, 'confidence') else 0.5

                segments_list.append({
                    "start_time": start_time,
                    "end_time": end_time,
                    "confidence": round(confidence, 3)
                })

            logos_data.append({
                "entity": logo_entity.description,
                "entity_id": logo_entity.entity_id,
                "segments": segments_list
            })

        # Update segment tags with logo data
        existing_tags = segment.tags or {}
        existing_tags["logos"] = logos_data
        existing_tags["analysis_timestamp"] = datetime.utcnow().isoformat()

        segment.tags = existing_tags
        db.commit()
        db.refresh(segment)

        logger.info(f"Video analysis complete. Found {len(logos_data)} logos in segment: {segment_id}")
        return segment

    except Exception as e:
        logger.error(f"Error analyzing video: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Video analysis failed: {str(e)}")


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=config.HOST, port=config.PORT)
