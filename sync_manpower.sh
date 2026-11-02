#!/usr/bin/env bash
set -euo pipefail

REF_FILE="./data-manpower/manpower valid.txt"
DB_CONTAINER="mte-fs-db"
DB_USER="mte"
DB_NAME="mte"

if [[ ! -f "$REF_FILE" ]]; then
    echo "Error: File $REF_FILE tidak ditemukan di lokasi $REF_FILE!"
    exit 1
fi

echo "1. Memperbarui struktur tabel database (kolom name & section)..."
docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <<EOF
ALTER TABLE public.manpower_profile ADD COLUMN IF NOT EXISTS name text NULL;
ALTER TABLE public.manpower_profile DROP CONSTRAINT IF EXISTS manpower_profile_section_check;
ALTER TABLE public.manpower_profile ADD CONSTRAINT manpower_profile_section_check 
CHECK (section IS NULL OR section = ANY (ARRAY['Big Wheel - PCH'::text, 'SPEX Mobile - Lighting'::text, 'SPEX Pumping - Fabrication'::text, 'LCE'::text, 'MTE'::text, 'Tyre'::text, 'Dept Head'::text, 'General Crew'::text]));
EOF

echo "2. Membaca data dari file referensi..."
declare -A REF_NAME
declare -A REF_CREW
declare -A REF_SECTION
declare -A REF_STATUS

while IFS=$'\t' read -r no nrp nama crew section || [[ -n "$no" ]]; do
    [[ "$no" == "No" || -z "$nrp" ]] && continue
    nrp=$(echo "$nrp" | tr -d '[:space:]')
    
    nama_clean=$(echo "$nama" | xargs)
    crew_clean=$(echo "$crew" | xargs)
    section_clean=$(echo "$section" | xargs)

    status=""
    if [[ "$crew_clean" =~ [Ss]taff ]]; then 
        status="Staff"
    else 
        status="Repairman"
    fi

    if [[ -n "$nrp" ]]; then
        REF_NAME["$nrp"]="$nama_clean"
        REF_CREW["$nrp"]="$crew_clean"
        REF_SECTION["$nrp"]="$section_clean"
        REF_STATUS["$nrp"]="$status"
    fi
done < "$REF_FILE"

echo "Total NRP di file referensi: ${#REF_NAME[@]}"

echo "3. Mengambil data dari database..."
mapfile -t DB_ROWS < <(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -F ',' -c \
    "SELECT nrp FROM manpower_profile;")

declare -A DB_EXISTS
for nrp in "${DB_ROWS[@]}"; do
    nrp=$(echo "$nrp" | tr -d '[:space:]')
    [[ -n "$nrp" ]] && DB_EXISTS["$nrp"]=1
done

echo "4. Membuat file SQL untuk sinkronisasi..."
SQL_FILE="sync_manpower.sql"
{
    echo "BEGIN;"
    
    for n in "${!REF_NAME[@]}"; do
        name_esc=$(echo "${REF_NAME[$n]}" | sed "s/'/''/g")
        crew_esc=$(echo "${REF_CREW[$n]}" | sed "s/'/''/g")
        sec_esc=$(echo "${REF_SECTION[$n]}" | sed "s/'/''/g")
        stat_esc="${REF_STATUS[$n]}"
        
        echo "INSERT INTO manpower_profile (nrp, name, crew, section, status, auto, updated_by, updated_at) VALUES ('$n', '$name_esc', '$crew_esc', '$sec_esc', '$stat_esc', FALSE, 'sync script complete', NOW()) ON CONFLICT (nrp) DO UPDATE SET name = EXCLUDED.name, crew = EXCLUDED.crew, section = EXCLUDED.section, status = EXCLUDED.status, updated_by = EXCLUDED.updated_by, updated_at = NOW();"
    done
    
    for db_nrp in "${!DB_EXISTS[@]}"; do
        if [[ -z "${REF_NAME[$db_nrp]+_}" ]]; then
            echo "DELETE FROM manpower_profile WHERE nrp = '$db_nrp';"
        fi
    done
    
    echo "COMMIT;"
} > "$SQL_FILE"

echo "5. Menjalankan SQL ke database..."
cat "$SQL_FILE" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME"

echo "=== SINKRONISASI SELESAI DENGAN SUKSES ==="
