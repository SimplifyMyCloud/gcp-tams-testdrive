"""Database models and connection management."""
from sqlalchemy import create_engine, Column, String, Integer, DateTime, JSON, Float
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from datetime import datetime
from .config import config

# Create engine
engine = create_engine(config.database_url, pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()


class Source(Base):
    """TAMS Source model."""

    __tablename__ = "sources"

    id = Column(String, primary_key=True)
    label = Column(String, nullable=False)
    description = Column(String)
    tags = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Flow(Base):
    """TAMS Flow model."""

    __tablename__ = "flows"

    id = Column(String, primary_key=True)
    source_id = Column(String, nullable=False)
    label = Column(String, nullable=False)
    description = Column(String)
    format = Column(String, nullable=False)
    codec = Column(String)
    tags = Column(JSON, default=dict)
    timerange_start = Column(String)
    timerange_end = Column(String)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)


class Segment(Base):
    """TAMS Segment model."""

    __tablename__ = "segments"

    id = Column(String, primary_key=True)
    flow_id = Column(String, nullable=False)
    timerange_start = Column(String, nullable=False)
    timerange_end = Column(String, nullable=False)
    duration = Column(Float)
    storage_uri = Column(String, nullable=False)
    size_bytes = Column(Integer)
    tags = Column(JSON, default=dict)
    created_at = Column(DateTime, default=datetime.utcnow)


def get_db():
    """Get database session."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def init_db():
    """Initialize database tables."""
    Base.metadata.create_all(bind=engine)
