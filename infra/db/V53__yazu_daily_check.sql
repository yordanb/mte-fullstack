-- V53: Tabel yazu_dc — Yazu Daily Check (sheet kedua: checklist harian unit)
-- Konsep sama dengan tabel yazu (P2H), beda kolom checklist & blok close-temuan.
-- Apply:  docker exec -i mte-fs-db psql -U mte -d mte < infra/db/V53__yazu_daily_check.sql
--
-- Header sheet (gid=0):
--   Waktu, ID Unit, Nama, NRP, Lokasi, HM, Layak Operasi, Akurasi, Link Lokasi,
--   Coment, LEVEL OLI, LEVEL COOLANT, LEVEL FUEL, KEBOCORAN OLI, KEBOCORAN
--   COOLANT, KEBOCORAN FUEL, KABEL TERKELUPAS, ATTACHMENT, APAR, (spacer),
--   STATUS CLOSE, PIC CLOSE, NRP CLOSE, TGL CLOSE, ACTION COMMENT

CREATE TABLE IF NOT EXISTS yazu_dc (
  id              SERIAL PRIMARY KEY,
  waktu           TIMESTAMPTZ NOT NULL,
  id_unit         VARCHAR(50)  NOT NULL,
  nama            VARCHAR(255),
  nrp             VARCHAR(50),
  lokasi          VARCHAR(255),
  hm              BIGINT,
  layak_operasi   VARCHAR(10),
  akurasi         INTEGER,
  link_lokasi     TEXT,
  coment          TEXT,
  level_oli            VARCHAR(10),   -- idx 10: LEVEL OLI
  level_coolant        VARCHAR(10),   -- idx 11: LEVEL COOLANT
  level_fuel           VARCHAR(10),   -- idx 12: LEVEL FUEL
  kebocoran_oli        VARCHAR(10),   -- idx 13: KEBOCORAN OLI
  kebocoran_coolant    VARCHAR(10),   -- idx 14: KEBOCORAN COOLANT
  kebocoran_fuel       VARCHAR(10),   -- idx 15: KEBOCORAN FUEL
  kabel_terkelupas     VARCHAR(10),   -- idx 16: KABEL TERKELUPAS
  attachment           VARCHAR(10),   -- idx 17: ATTACHMENT
  apar                 VARCHAR(50),   -- idx 18: APAR (ADA / TIDAK ADA / LOW PRESSURE)
  status_close         VARCHAR(50),   -- idx 20: "TEMUAN CLOSED" / kosong
  pic_close            VARCHAR(255),  -- idx 21: PIC yang close temuan
  nrp_close            VARCHAR(50),   -- idx 22: NRP PIC
  tgl_close            VARCHAR(50),   -- idx 23: teks bebas di sheet, disimpan apa adanya
  action_comment       TEXT,          -- idx 24
  synced_at       TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(waktu, id_unit)
);

CREATE INDEX IF NOT EXISTS idx_yazu_dc_waktu     ON yazu_dc (waktu);
CREATE INDEX IF NOT EXISTS idx_yazu_dc_unit      ON yazu_dc (id_unit);
CREATE INDEX IF NOT EXISTS idx_yazu_dc_unit_day  ON yazu_dc (id_unit, (waktu::date));

-- Log sync (bentuk sama dengan yazu_sync_log)
CREATE TABLE IF NOT EXISTS yazu_dc_sync_log (
  id          SERIAL PRIMARY KEY,
  started_at  TIMESTAMPTZ DEFAULT NOW(),
  finished_at TIMESTAMPTZ,
  status      VARCHAR(20),        -- success | error
  rows_total  INTEGER,
  rows_upserted INTEGER,
  error_msg   TEXT
);

-- Catatan: menu "Yazu Daily Check" memakai permission menu `yazu` yang sudah ada
-- (pola yang sama dengan menu SS AB yang memakai permission `ss`), jadi tabel
-- role_permissions tidak perlu diubah.
