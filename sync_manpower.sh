#!/usr/bin/env bash
# sync_manpower.sh — jalankan di VPS (memerlukan docker & psql di container mte-fs-db)
set -euo pipefail

MANPOWER_DIR="./data-manpower"
DB_CONTAINER="mte-fs-db"
DB_USER="mte"
DB_NAME="mte"

# ---------- 1. Bangun referensi dari file .txt ----------
declare -A REF_CREW
declare -A REF_STATUS

for f in "$MANPOWER_DIR"/*.txt; do
    base=$(basename "$f" .txt)
    crew=""
    status=""

    case "$base" in
        *tyre*) crew="Tyre" ;;
        *"big wheel"*) crew="Big Wheel" ;;
        *pch*) crew="PCH" ;;
        *mobile*) crew="Mobile" ;;
        *lighting*) crew="Lighting" ;;
        *pumping*) crew="Pumping" ;;
        *"operator tadano"*) crew="Mobile" ;;
        *"dept head"*) crew="General Crew" ;;
        *lce*) crew="LCE" ;;
    esac

    if [[ "$base" =~ (mekanik|repairman|operator) ]]; then
        status="Repairman"
    elif [[ "$base" =~ staff ]]; then
        status="Staff"
    fi

    if [[ -n "$crew" && -n "$status" ]]; then
        while IFS= read -r line; do
            nrp=$(echo "$line" | tr -d ' \t\r')
            [[ -n "$nrp" ]] && REF_CREW["$nrp"]="$crew" && REF_STATUS["$nrp"]="$status"
        done < "$f"
    fi
done

echo "Total NRP di referensi: ${#REF_CREW[@]}"

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

# ---------- 4. Tampilkan ringkasan ----------
echo
echo "=== RINGKASAN ==="
echo "INSERT baru: ${#TO_INSERT[@]}"
for n in "${TO_INSERT[@]}"; do echo "  + $n (${REF_CREW[$n]} - ${REF_STATUS[$n]})"; done

echo "UPDATE crew/status: ${#TO_UPDATE[@]}"
for n in "${TO_UPDATE[@]}"; do
    echo "  ~ $n: [${DB_CREW[$n]}/${DB_STATUS[$n]}] -> [${REF_CREW[$n]}/${REF_STATUS[$n]}]"
done

echo "Di DB tapi TIDAK di referensi (resign/keluar): ${#NOT_IN_REF[@]}"
for n in "${NOT_IN_REF[@]}"; do echo "  - $n (${DB_CREW[$n]} - ${DB_STATUS[$n]})"; done

# ---------- 5. Generate SQL ----------
SQL_FILE="sync_manpower.sql"
{
    echo "BEGIN;"
    for n in "${TO_INSERT[@]}"; do
        echo "INSERT INTO manpower_profile (nrp, crew, status, auto, updated_by, updated_at) VALUES ('$n', '${REF_CREW[$n]}', '${REF_STATUS[$n]}', FALSE, 'sync from data-manpower', NOW()) ON CONFLICT (nrp) DO UPDATE SET crew = EXCLUDED.crew, status = EXCLUDED.status, auto = FALSE, updated_by = EXCLUDED.updated_by, updated_at = NOW();"
    done
    for n in "${TO_UPDATE[@]}"; do
        echo "UPDATE manpower_profile SET crew = '${REF_CREW[$n]}', status = '${REF_STATUS[$n]}', auto = FALSE, updated_by = 'sync from data-manpower', updated_at = NOW() WHERE nrp = '$n';"
    done
    for n in "${NOT_IN_REF[@]}"; do
        # Set status NULL (diizinkan constraint) untuk yang tidak ada di referensi
        echo "UPDATE manpower_profile SET status = NULL, crew = NULL, auto = FALSE, updated_by = 'sync: not in reference', updated_at = NOW() WHERE nrp = '$n' AND status IS NOT NULL;"
    done
    echo "COMMIT;"
} > "$SQL_FILE"

echo
echo "File SQL: $SQL_FILE"
echo "Jalankan:"
echo "  cat $SQL_FILE | docker exec -i $DB_CONTAINER psql -U $DB_USER -d $DB_NAME"