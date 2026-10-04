import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useEffect, useState } from 'react';
import { fetchResults, fetchFleetAlerts, uploadExcel } from '../api/client';
import { MetricCards, Trend, VesselTable } from '../components/Widgets';
export function Dashboard() {
    const [vessel, setVessel] = useState('TL986');
    const [unit, setUnit] = useState('ENGINE');
    const [rows, setRows] = useState([]);
    const load = async () => setRows(await fetchResults(vessel, unit || undefined));
    useEffect(() => { load(); }, []);
    const crit = rows.filter((r) => r.condition !== 'NORMAL').length;
    return (_jsxs("div", { className: "flex flex-col gap-6", children: [_jsxs("div", { className: "flex gap-2", children: [_jsx("input", { className: "rounded-lg border px-3 py-2", value: vessel, onChange: (e) => setVessel(e.target.value.toUpperCase()), placeholder: "TL986" }), _jsx("input", { className: "rounded-lg border px-3 py-2", value: unit, onChange: (e) => setUnit(e.target.value.toUpperCase()), placeholder: "ENGINE" }), _jsx("button", { className: "rounded-lg bg-brand-500 px-4 py-2 text-white", onClick: load, children: "Cari" })] }), _jsx(MetricCards, { total: rows.length, critical: crit, normal: rows.length - crit }), _jsx(Trend, { rows: rows }), _jsx(VesselTable, { rows: rows })] }));
}
export function FleetPage() {
    const [prefix, setPrefix] = useState('TL');
    const [rows, setRows] = useState([]);
    const load = async () => setRows(await fetchFleetAlerts(prefix));
    useEffect(() => { load(); }, []);
    return (_jsxs("div", { className: "flex flex-col gap-4", children: [_jsx("h2", { className: "text-theme-xl font-semibold", children: "Fleet Alert (status terakhir non-NORMAL)" }), _jsxs("div", { className: "flex gap-2", children: [_jsx("input", { className: "rounded-lg border px-3 py-2", value: prefix, onChange: (e) => setPrefix(e.target.value.toUpperCase().slice(0, 2)) }), _jsx("button", { className: "rounded-lg bg-brand-500 px-4 py-2 text-white", onClick: load, children: "Tampilkan" })] }), _jsx("ul", { className: "rounded-2xl border bg-white p-5", children: rows.map((r) => (_jsxs("li", { children: [r.vesselid, " / ", r.unit_id, " \u2014 ", r.condition, " (", r.sample_date, ")"] }, `${r.vesselid}-${r.unit_id}`))) })] }));
}
export function ImportPage() {
    const [msg, setMsg] = useState('');
    const send = async (dry) => {
        const el = document.getElementById('xlsx');
        const f = el.files?.[0];
        if (!f)
            return;
        setMsg('memproses...');
        try {
            const r = await uploadExcel(f, dry);
            setMsg(dry ? `Dry-run: ok=${r.ok} fail=${r.fail}` : `Commit: ok=${r.ok} import=${r.import_id}`);
        }
        catch (e) {
            setMsg(`gagal: ${String(e)}`);
        }
    };
    return (_jsxs("div", { className: "flex flex-col gap-4 rounded-2xl border bg-white p-5", children: [_jsx("h2", { className: "font-semibold", children: "Import Excel" }), _jsx("input", { type: "file", accept: ".xlsx", id: "xlsx" }), _jsxs("div", { className: "flex gap-2", children: [_jsx("button", { className: "rounded-lg border px-4 py-2", onClick: () => send(true), children: "Dry-run" }), _jsx("button", { className: "rounded-lg bg-brand-500 px-4 py-2 text-white", onClick: () => send(false), children: "Commit" })] }), _jsx("p", { children: msg })] }));
}
