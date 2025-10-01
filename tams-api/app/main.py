"""TAMS API - Main application."""
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List
from datetime import datetime
import logging

from .config import config
from .database import get_db, init_db, Source, Flow, Segment
from .models import (
    SourceCreate,
    SourceResponse,
    FlowCreate,
    FlowResponse,
    SegmentCreate,
    SegmentResponse,
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


@app.post("/segments", response_model=SegmentResponse, status_code=201)
async def create_segment(
    segment: SegmentCreate,
    file: UploadFile = File(...),
    db: Session = Depends(get_db),
):
    """Create a new segment with media upload."""
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

    # Generate signed URL
    url = storage_manager.get_segment_url(segment.flow_id, segment_id)

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


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host=config.HOST, port=config.PORT)
