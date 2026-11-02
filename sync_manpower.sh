#!/usr/bin/env bash
set -euo pipefail

REF_FILE="./data-manpower/manpower_valid.txt"
DB_CONTAINER="mte-fs-db"
DB_USER="mte"
DB_NAME="mte"

if [[ ! -f "$REF_FILE" ]]; then
    echo "Error: File $REF_FILE tidak ditemukan!"
    exit 1
fi

declare -A REF_CREW
declare -A REF_STATUS

while IFS=$'\t' read -r no nrp nama crew section || [[ -n "$no" ]]; do
    [[ "$no" == "No" || -z "$nrp" ]] && continue
    nrp=$(echo "$nrp" | tr -d '[:space:]')
    crew_clean=$(echo "$crew" | xargs)
    section_clean=$(echo "$section" | xargs)

    status=""
    if [[ "$crew_clean" =~ [Ss]taff ]]; then
        status="Staff"
    elif [[ "$crew_clean" =~ ([Mm]ekanik|[Rr]epairman|[Oo]perator) ]]; then
        status="Repairman"
    else
        if [[ "$section_clean" =~ [Ss]taff ]]; then status="Staff"
        else status="Repairman"; fi
    fi

    if [[ -n "$nrp" ]]; then
        REF_CREW["$nrp"]="$crew_clean"
        REF_STATUS["$nrp"]="$status"
    fi
done < "$REF_FILE"

echo "Total NRP di referensi: ${#REF_CREW[@]}"

mapfile -t DB_ROWS < <(docker exec -i "$DB_CONTAINER" psql -U "$DB_USER" -d "$DB_NAME" -t -A -F ',' -c \
    "SELECT nrp, COALESCE(crew,''), COALESCE(status,'') FROM manpower_profile ORDER BY nrp;")

declare -A DB_CREW
declare -A DB_STATUS

for row in "${DB_ROWS[@]}"; do
    IFS=',' read -r nrp crew status <<< "$row"
    [[ -n "$nrp" ]] && DB_CREW["$nrp"]="$crew" && DB_STATUS["$nrp"]="$status"
done

echo "Total NRP di database: ${#DB_CREW[@]}"

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

SQL_FILE="sync_manpower.sql"
{
    echo "BEGIN;"
    for n in "${TO_INSERT[@]}"; do
        echo "INSERT INTO manpower_profile (nrp, crew, status, auto, updated_by, updated_at) VALUES ('$n', '${REF_CREW[$n]}', '${REF_STATUS[$n]}', FALSE, 'sync from manpower_valid.txt', NOW()) ON CONFLICT (nrp) DO UPDATE SET crew = EXCLUDED.crew, status = EXCLUDED.status, auto = FALSE, updated_by = EXCLUDED.updated_by, updated_at = NOW();"
    done
    for n in "${TO_UPDATE[@]}"; do
        echo "UPDATE manpower_profile SET crew = '${REF_CREW[$n]}', status = '${REF_STATUS[$n]}', auto = FALSE, updated_by = 'sync from manpower_valid.txt', updated_at = NOW() WHERE nrp = '$n';"
    done
    for n in "${NOT_IN_REF[@]}"; do
        # Gunakan NULL untuk status agar lolos check constraint
        echo "UPDATE manpower_profile SET status = NULL, crew = NULL, auto = FALSE, updated_by = 'sync: not in valid ref', updated_at = NOW() WHERE nrp = '$n' AND (status IS NOT NULL OR crew IS NOT NULL);"
    done
    echo "COMMIT;"
} > "$SQL_FILE"

echo "Selesai generate $SQL_FILE"
