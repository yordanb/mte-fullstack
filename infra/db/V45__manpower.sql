-- V45: Manpower Inovasi — snapshot bulanan RptInnovatorMonthly.
--
-- Sumber: data sample excel/data mp/RptInnovatorMonthly <Bln> <Thn>.xlsx
-- Satu baris = satu orang (NRP) pada bulan tersebut. Data per bulan bisa
-- berubah (orang masuk/keluar/pindah dept), jadi setiap bulan disimpan sebagai
-- snapshot tersendiri dan tidak saling menimpa.
--
-- Kunci unik (periode, nrp):
--   * import ulang bulan yang sama -> baris diperbarui (bukan diduplikasi)
--   * baris yang tidak ada lagi di file terbaru bulan tsb -> dihapus, sehingga
--     snapshot selalu sama persis dengan file terakhir yang di-upload
--
-- Data ini dipakai untuk menghitung coverage pembuatan SS pada bulan tertentu:
--   coverage innovator = orang dengan INNOVATOR SS = 1 / total manpower
--   SS per manpower    = total JUMLAH SS CLOSED / total manpower

CREATE TABLE IF NOT EXISTS manpower_month (
  id               BIGSERIAL PRIMARY KEY,
  periode          DATE NOT NULL,                 -- selalu tanggal 1 bulan snapshot
  nrp              TEXT NOT NULL,
  nama             TEXT NULL,
  jabatan          TEXT NULL,
  dept             TEXT NULL,                     -- SPL1 / SPL2 / STYR / ...
  divisi           TEXT NULL,                     -- PLAN / OPRT / ...
  distrik          TEXT NULL,                     -- KIDE

  -- DT / QCP / QCC (jumlah closed + peran)
  dt_closed        INTEGER NOT NULL DEFAULT 0,
  dt_fasilitator   INTEGER NOT NULL DEFAULT 0,
  dt_leader        INTEGER NOT NULL DEFAULT 0,
  dt_member        INTEGER NOT NULL DEFAULT 0,
  qcp_closed       INTEGER NOT NULL DEFAULT 0,
  qcp_fasilitator  INTEGER NOT NULL DEFAULT 0,
  qcp_leader       INTEGER NOT NULL DEFAULT 0,
  qcp_member       INTEGER NOT NULL DEFAULT 0,
  qcc_closed       INTEGER NOT NULL DEFAULT 0,
  qcc_fasilitator  INTEGER NOT NULL DEFAULT 0,
  qcc_leader       INTEGER NOT NULL DEFAULT 0,
  qcc_member       INTEGER NOT NULL DEFAULT 0,

  -- SS per kelas + total
  ss_a             INTEGER NOT NULL DEFAULT 0,
  ss_b             INTEGER NOT NULL DEFAULT 0,
  ss_c             INTEGER NOT NULL DEFAULT 0,
  ss_d             INTEGER NOT NULL DEFAULT 0,
  ss_e             INTEGER NOT NULL DEFAULT 0,
  ss_f             INTEGER NOT NULL DEFAULT 0,
  ss_closed        INTEGER NOT NULL DEFAULT 0,    -- JUMLAH SS CLOSED

  -- Penanda kontributor bulan tsb (0/1 di sumber)
  innovator_ss     INTEGER NOT NULL DEFAULT 0,
  innovator_qcc    INTEGER NOT NULL DEFAULT 0,
  innovator_all    INTEGER NOT NULL DEFAULT 0,

  import_id        TEXT NULL,                     -- imports.id (uuid) sebagai teks
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT manpower_month_key UNIQUE (periode, nrp)
);

CREATE INDEX IF NOT EXISTS idx_manpower_periode ON manpower_month (periode DESC);
CREATE INDEX IF NOT EXISTS idx_manpower_dept ON manpower_month (dept);
CREATE INDEX IF NOT EXISTS idx_manpower_divisi ON manpower_month (divisi);
CREATE INDEX IF NOT EXISTS idx_manpower_periode_dept ON manpower_month (periode, dept);

DROP TRIGGER IF EXISTS trg_manpower_month_updated ON manpower_month;
CREATE TRIGGER trg_manpower_month_updated BEFORE UPDATE ON manpower_month
FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Menu "manpower" pada matriks izin (grup Agent, bersebelahan dengan SS).
ALTER TABLE role_permissions DROP CONSTRAINT IF EXISTS role_permissions_menu_check;
ALTER TABLE role_permissions ADD CONSTRAINT role_permissions_menu_check
  CHECK (menu IN (
    'dashboard','dbr','performance','activity','timeline','equipment',
    'fui','sugfui','fureport','project','bomak','staging','mom','riwayat',
    'import','ppm','measurement','yazu','ewacs','tarsupport','ss','proker',
    'prokerbooster','prokerinjector','manpower'
  ));

-- Izin mengikuti menu "ss" supaya tidak perlu diatur ulang di halaman Users.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete)
SELECT role, 'manpower', can_view, can_add, can_edit, can_delete
FROM role_permissions WHERE menu = 'ss'
ON CONFLICT (role, menu) DO NOTHING;

-- Jaring pengaman bila baris "ss" belum pernah di-seed.
INSERT INTO role_permissions(role, menu, can_view, can_add, can_edit, can_delete) VALUES
  ('admin',        'manpower', TRUE, TRUE, TRUE, TRUE),
  ('inputer',      'manpower', TRUE, TRUE, TRUE, FALSE),
  ('mekanik',      'manpower', TRUE, TRUE, TRUE, FALSE),
  ('planner',      'manpower', TRUE, TRUE, TRUE, FALSE),
  ('adm te',       'manpower', TRUE, TRUE, TRUE, FALSE),
  ('group leader', 'manpower', TRUE, FALSE, FALSE, FALSE),
  ('section head', 'manpower', TRUE, FALSE, FALSE, FALSE),
  ('viewer',       'manpower', TRUE, FALSE, FALSE, FALSE)
ON CONFLICT (role, menu) DO NOTHING;
