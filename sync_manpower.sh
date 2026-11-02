#!/usr/bin/env bash
set -euo pipefail

REF_FILE="./data-manpower/manpower valid.txt"
DB_CONTAINER="mte-fs-db"
DB_USER="mte"
DB_NAME="mte"

if [[ ! -f "$REF_FILE" ]]; then
    echo "Error: File $REF_FILE tidak ditemukan!"
    exit 1
fi

echo "1. Memperbarui struktur dan constraint tabel..."
docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" <<EOF
ALTER TABLE public.manpower_profile ADD COLUMN IF NOT EXISTS name text NULL;
ALTER TABLE public.manpower_profile DROP CONSTRAINT IF EXISTS manpower_profile_section_check;
ALTER TABLE public.manpower_profile ADD CONSTRAINT manpower_profile_section_check 
CHECK (section IS NULL OR section = ANY (ARRAY['Big Wheel - PCH'::text, 'SPEX Mobile - Lighting'::text, 'SPEX Pumping - Fabrication'::text, 'LCE'::text, 'MTE'::text, 'Tyre'::text, 'Dept Head'::text, 'General Crew'::text]));
EOF

# Fungsi mapping Section agar sesuai constraint DB
map_section() {
    local raw="$1"
    if [[ "$raw" =~ ([Bb]ig\ [Ww]heel|[Pp][Cc][Hh]) ]]; then echo "Big Wheel - PCH"; return; fi
    if [[ "$raw" =~ ([Mm]obile|[Ll]ighting) ]]; then echo "SPEX Mobile - Lighting"; return; fi
    if [[ "$raw" =~ ([Pp]umping|[Ff]abrication) ]]; then echo "SPEX Pumping - Fabrication"; return; fi
    if [[ "$raw" =~ [Ll][Cc][Ee] ]]; then echo "LCE"; return; fi
    if [[ "$raw" =~ [Mm][Tt][Ee] ]]; then echo "MTE"; return; fi
    if [[ "$raw" =~ [Tt]yre ]]; then echo "Tyre"; return; fi
    if [[ "$raw" =~ [Dd]ept\ [Hh]ead ]]; then echo "Dept Head"; return; fi
    echo "General Crew"
}

map_crew() {
    local raw="$1"
    if [[ "$raw" =~ [Tt]yre ]]; then echo "Tyre"; return; fi
    if [[ "$raw" =~ ([Bb]ig\ [Ww]heel) ]]; then echo "Big Wheel"; return; fi
    if [[ "$raw" =~ [Pp][Cc][Hh] ]]; then echo "PCH"; return; fi
    if [[ "$raw" =~ ([Mm]obile|[Tt]adano) ]]; then echo "Mobile"; return; fi
    if [[ "$raw" =~ [Ll]ighting ]]; then echo "Lighting"; return; fi
    if [[ "$raw" =~ [Pp]umping ]]; then echo "Pumping"; return; fi
    if [[ "$raw" =~ [Ll][Cc][Ee] ]]; then echo "LCE"; return; fi
    if [[ "$raw" =~ [Mm][Tt][Ee] ]]; then echo "MTE"; return; fi
    echo "General Crew"
}

declare -A REF_NAME REF_CREW REF_SECTION REF_STATUS

# Membaca 6 kolom: No, NRP, Nama, Crew, Section, Status
while IFS=$'\t' read -r no nrp nama crew section status_file || [[ -n "$no" ]]; do
    [[ "$no" == "No" || -z "$nrp" ]] && continue
    nrp=$(echo "$nrp" | tr -d '[:space:]')
    
    # Mapping data agar aman masuk DB
    REF_NAME["$nrp"]=$(echo "$nama" | xargs)
    REF_CREW["$nrp"]=$(map_crew "$crew")
    REF_SECTION["$nrp"]=$(map_section "$section")
    
    if [[ "$crew" =~ [Ss]taff || "$status_file" =~ [Ss]taff ]]; then
        REF_STATUS["$nrp"]="Staff"
    else
        REF_STATUS["$nrp"]="Repairman"
    fi
done < "$REF_FILE"

echo "Total NRP di referensi: ${#REF_NAME[@]}"

mapfile -t DB_ROWS < <(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -F ',' -c "SELECT nrp FROM manpower_profile;")
declare -A DB_EXISTS
for n in "${DB_ROWS[@]}"; do DB_EXISTS["$(echo "$n" | tr -d '[:space:]')"]=1; done

SQL_FILE="sync_manpower.sql"
{
    echo "BEGIN;"
    for n in "${!REF_NAME[@]}"; do
        name_esc=$(echo "${REF_NAME[$n]}" | sed "s/'/''/g")
        crew_esc="${REF_CREW[$n]}"
        sec_esc="${REF_SECTION[$n]}"
        stat_esc="${REF_STATUS[$n]}"
        echo "INSERT INTO manpower_profile (nrp, name, section, crew, status, auto, updated_by, updated_at) VALUES ('$n', '$name_esc', '$sec_esc', '$crew_esc', '$stat_esc', FALSE, 'sync script complete', NOW()) ON CONFLICT (nrp) DO UPDATE SET name = EXCLUDED.name, section = EXCLUDED.section, crew = EXCLUDED.crew, status = EXCLUDED.status, updated_at = NOW();"
    done
    for db_nrp in "${!DB_EXISTS[@]}"; do
        if [[ -z "${REF_NAME[$db_nrp]+_}" ]]; then
            echo "DELETE FROM manpower_profile WHERE nrp = '$db_nrp';"
        fi
    done
    echo "COMMIT;"
} > "$SQL_FILE"

echo "5. Menjalankan SQL..."
cat "$SQL_FILE" | docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME"
echo "=== SINKRONISASI SELESAI ==="
