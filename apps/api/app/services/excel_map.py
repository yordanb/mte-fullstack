"""Mapping header Excel (row 4) -> kolom DB. Menangani typo report."""
HEADER_MAP = {
    "Unit Id": "unit_id", "Model": "model", "Make": "make",
    "District": "district", "Lab Name": "lab_name", "Lab No": "lab_no",
    "Vesselid": "vesselid", "Customer ID": "customer_id",
    "Companyname": "companyname", "Oil Brand": "oil_brand",
    "Oil Change": "oil_change", "Oil Weight": "oil_weight",
    "Driver": "driver", "Oil Capacity": "oil_capacity",
    "Oil Capacity Units": "oil_capacity_units",
    "Unit Time": "unit_time", "Unit Time Oils": "unit_time_oils",
    "Oil Time Units": "oil_time_units", "User Sample Id": "user_sample_id",
    "Sample Date": "sample_date", "Date Taken": "date_taken",
    "N Al": "n_al", "N Cr": "n_cr", "N Cu": "n_cu", "N Fe": "n_fe",
    "N Pb": "n_pb", "N Sn": "n_sn", "N K": "n_k", "N Na": "n_na",
    "N Water": "n_water", "N Oxi": "n_oxi", "N Visc": "n_visc",
    "N Gly": "n_gly", "NFuel": "n_fuel", "N Tbn": "n_tbn",
    "N Nitr": "n_nitr", "N Soot": "n_soot", "N Tan": "n_tan",
    "N Mg": "n_mg", "N Ag": "n_ag", "N Zn": "n_zn",
    "N Al Max": "n_al_max", "N Cr Max": "n_cr_max", "N Cu Max": "n_cu_max",
    "N Fe Max": "n_fe_max", "N Pb Max": "n_pb_max", "N Sn Max": "n_sn_max",
    "N K Max": "n_k_max", "N Na Max": "n_na_max",
    "N Water Max": "n_water_max", "NO xi Max": "n_oxi_max",
    "N Visc Max": "n_visc_max", "N Gly Max": "n_gly_max",
    "N Fuel Max": "n_fuel_max", "N Tbn Max": "n_tbn_max",
    "N Nitr Max": "n_nitr_max", "N Soot Max": "n_soot_max",
    "N Tan Max": "n_tan_max", "N Mg Max": "n_mg_max",
    "N Ag Max": "n_ag_max", "N Zn Max": "n_zn_max",
    "Grade Al": "grade_al", "Grade C": "grade_cr",
    "Grade Cu": "grade_cu", "Grade Fe": "grade_fe",
    "Grade Pb": "grade_pb", "Grade Sn": "grade_sn",
    "Grade Si": "grade_si", "Grade K": "grade_k",
    "Grade Na": "grade_na", "Grade Water": "grade_water",
    "Grade Visc": "grade_visc", "Grade Oxi": "grade_oxi",
    "Grade Gly": "grade_gly", "Grade Fuel": "grade_fuel",
    "Gradet Bn": "grade_tbn", "Grade Nitr": "grade_nitr",
    "Grade Soot": "grade_soot", "Grade Tan": "grade_tan",
    "Grade Mg": "grade_mg", "Grade Ag": "grade_ag",
    "Grade Zn": "grade_zn",
    "Al": "al", "Cr": "cr", "Cu": "cu", "Fe": "fe",
    "Pb": "pb", "Sn": "sn", "Si": "si", "K": "k", "Na": "na",
    "Water": "water", "Visc": "visc", "Oxi": "oxi",
    "Gly": "gly", "Fuel": "fuel", "Tbn": "tbn",
    "Nitr": "nitr", "Soot": "soot", "Tan": "tan",
    "Mg": "mg", "Ag": "ag", "Zn": "zn",
    "English Description": "english_description",
    "NVOSAID": "nvosaid", "Condition": "condition",
    "ISO4406": "iso4406", "PQIndex": "pqindex",
    "colorcode": "colorcode", "empat_um": "empat_um",
    "enam_um": "enam_um", "limabelas_um": "limabelas_um",
    "seq_I": "seq_i", "seq_I_code": "seq_i_code",
    "seq_II": "seq_ii", "seq_III": "seq_iii",
}

HEADER_ROW = 4
DATA_START_ROW = 5
SHEET = "Rpt_Data_All_Lab"


def parse_lab_no(v):
    if v is None or v == "":
        raise ValueError("Lab No kosong")
    return int(str(v).strip())


def norm_vessel(v):
    return str(v).strip().upper() if v else None
