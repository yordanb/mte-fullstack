#!/usr/bin/env bash
# sync_manpower.sh — Sumber utama: data-manpower/manpower_valid.txt
set -euo pipefail

REF_FILE="./data-manpower/manpower_valid.txt"
DB_CONTAINER="mte-fs-db"
DB_USER="mte"
DB_NAME="mte"

if [[ ! -f "$REF_FILE" ]]; then
    echo "Error: File $REF_FILE tidak ditemukan!"
    exit 1
fi

# ---------- 1. Bangun referensi dari manpower_valid.txt ----------
declare -A REF_CREW
declare -A REF_STATUS

# Lewati header (baris 1), baca kolom: NRP(2), Crew(4), Section(5)
# Menggunakan AWK untuk handle tab dan spasi
while IFS=$'\t' read -r no nrp nama crew section || [[ -n "$no" ]]; do
    # Lewati baris header atau baris kosong
    [[ "$no" == "No" || -z "$nrp" ]] && continue
    
    # Bersihkan whitespace
    nrp=$(echo "$nrp" | tr -d '[:space:]')
    crew_clean=$(echo "$crew" | xargs)
    section_clean=$(echo "$section" | xargs)

    # Tentukan Status berdasarkan Crew/Section
    status=""
    if [[ "$crew_clean" =~ [Ss]taff ]]; then
        status="Staff"
    elif [[ "$crew_clean" =~ ([Mm]ekanik|[Rr]epairman|[Oo]perator) ]]; then
        status="Repairman"
    else
        # Fallback: jika tidak ada kata kunci, cek Section
        if [[ "$section_clean" =~ [Ss]taff ]]; then status="Staff"
        else status="Repairman"; fi
    fi

    # Simpan ke map
    if [[ -n "$nrp" ]]; then
        REF_CREW["$nrp"]="$crew_clean"
        REF_STATUS["$nrp"]="$status"
    fi
done < "$REF_FILE"

echo "Total NRP di referensi valid: ${#REF_CREW[@]}"

# ---------- 2. Ambil data DB ----------
mapfile -t DB_ROWS < <(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -F ',' -c \
    "SELECT nrp, COALESCE(crew,''), COALESCE(status,'') FROM manpower_profile ORDER BY nrp;")

declare -A DB_CREW
declare -A DB_STATUS

for row in "${DB_ROWS[@]}"; do
    IFS=',' read -r nrp crew status <<< "$row"
    [[ -n "$nrp" ]] && DB_CREW["$nrp"]="$crew" && DB_STATUS["$nrp"]="$status"
done

echo "Total NRP di database: ${#DB_CREW[@]}"

# ---------- 3. Bandingkan ----------
TO_INSERT=()
TO_UPDATE=()
NOT_IN_REF=()

for nrp in "${!REF_CREW[@]}"; do
    if [[ -z "${DB_CREW[$nrp]+_}" ]]; then
        TO_INSERT+=("$nrp")
    elif [[ "${DB_CREW[$nrp]}" != "${REF_CREW[$nrp]}" || "${DB_STATUS[$nrp]}" != "${REF_STATUS[$nrp]}" ]]; then
        TO_UPDATE+=("$nrp")
    fi
done

for nrp in "${!DB_CREW[@]}"; do
    if [[ -z "${REF_CREW[$nrp]+_}" ]]; then
        NOT_IN_REF+=("$nrp")
    fi
done

# ---------- 4. Generate SQL ----------
SQL_FILE="sync_manpower.sql"
{
    echo "BEGIN;"
    # INSERT/UPDATE yang ada di referensi
    for n in "${TO_INSERT[@]}"; do
        echo "INSERT INTO manpower_profile (nrp, crew, status, auto, updated_by, updated_at) VALUES ('$n', '${REF_CREW[$n]}', '${REF_STATUS[$n]}', FALSE, 'sync from manpower_valid.txt', NOW());"
    done
    for n in "${TO_UPDATE[@]}"; do
        echo "UPDATE manpower_profile SET crew = '${REF_CREW[$n]}', status = '${REF_STATUS[$n]}', auto = FALSE, updated_by = 'sync from manpower_valid.txt', updated_at = NOW() WHERE nrp = '$n';"
    done
    # Resign/Keluar (tidak ada di referensi)
    for n in "${NOT_IN_REF[@]}"; do
        echo "UPDATE manpower_profile SET status = NULL, crew = NULL, auto = FALSE, updated_by = 'sync: not in valid ref', updated_at = NOW() WHERE nrp = '$n' AND status IS NOT NULL;"
    done
    echo "COMMIT;"
} > "$SQL_FILE"

echo
echo "Analisis Selesai:"
echo " - Akan di-INSERT: ${#TO_INSERT[@]}"
echo " - Akan di-UPDATE: ${#TO_UPDATE[@]}"
echo " - Akan di-NULL (Resign): ${#NOT_IN_REF[@]}"
echo
echo "File SQL: $SQL_FILE"
echo "Jalankan perintah ini di VPS:"
echo "  cat $SQL_FILE | docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME"
