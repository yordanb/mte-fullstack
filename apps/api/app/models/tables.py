from __future__ import annotations
import uuid
from datetime import datetime
from sqlalchemy import BigInteger, Text, Numeric, Integer, String, CHAR, DateTime
from sqlalchemy import ForeignKey, text
from sqlalchemy.dialects.postgresql import UUID as PG_UUID
from sqlalchemy.orm import Mapped, mapped_column
from app.db.session import Base

class Import(Base):
    __tablename__ = "imports"
    id: Mapped[uuid.UUID] = mapped_column(PG_UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    filename: Mapped[str] = mapped_column(Text)
    sheet: Mapped[str] = mapped_column(Text, default="Rpt_Data_All_Lab")
    status: Mapped[str] = mapped_column(String(20), default="PENDING")
    total_rows: Mapped[int] = mapped_column(Integer, default=0)
    ok_rows: Mapped[int] = mapped_column(Integer, default=0)
    fail_rows: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), server_default=text("now()"))

class OilLabResult(Base):
    __tablename__ = "oil_lab_result"
    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    lab_no: Mapped[int] = mapped_column(BigInteger, unique=True, nullable=False)
    import_id: Mapped[uuid.UUID | None] = mapped_column(PG_UUID(as_uuid=True), ForeignKey("imports.id"), nullable=True)
    vesselid: Mapped[str | None] = mapped_column(String(50), nullable=True, index=True)
    unit_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    model: Mapped[str | None] = mapped_column(String(100))
    make: Mapped[str | None] = mapped_column(String(100))
    district: Mapped[str | None] = mapped_column(String(50))
    lab_name: Mapped[str | None] = mapped_column(String(50))
    customer_id: Mapped[str | None] = mapped_column(String(100))
    companyname: Mapped[str | None] = mapped_column(String(100))
    oil_brand: Mapped[str | None] = mapped_column(String(100))
    oil_change: Mapped[str | None] = mapped_column(String(20))
    oil_weight: Mapped[str | None] = mapped_column(String(50))
    oil_capacity: Mapped[int | None] = mapped_column(Integer)
    oil_capacity_units: Mapped[str | None] = mapped_column(String(20))
    unit_time: Mapped[int | None] = mapped_column(Integer)
    unit_time_oils: Mapped[int | None] = mapped_column(Integer)
    user_sample_id: Mapped[str | None] = mapped_column(String(50))
    sample_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    date_taken: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    condition: Mapped[str | None] = mapped_column("condition", String(20))
    english_description: Mapped[str | None] = mapped_column(Text)
    nvosaid: Mapped[str | None] = mapped_column(String(50))
    # kolom numerik/grade lengkap ada di DDL V1; model ORM menyimpan subset inti
    # + payload JSON untuk sisa kolom agar 1:1 Excel tanpa 100 atribut manual.
    # Full wide-table tetap di Postgres (V1 sql); ORM hanya baca kolom query utama.
    fe: Mapped[float | None] = mapped_column(Numeric(10, 2))
    al: Mapped[float | None] = mapped_column(Numeric(10, 2))
