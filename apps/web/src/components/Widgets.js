import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
export function MetricCards({ total, critical, normal }) {
    const cards = [
        { label: 'Total sampel (20 terbaru)', value: total },
        { label: 'CRITICAL', value: critical },
        { label: 'NORMAL', value: normal },
    ];
    return (_jsx("div", { className: "grid grid-cols-1 gap-4 sm:grid-cols-3", children: cards.map((c) => (_jsxs("div", { className: "rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03]", children: [_jsx("p", { className: "text-theme-sm text-gray-500", children: c.label }), _jsx("p", { className: "mt-2 text-title-sm font-bold", children: c.value })] }, c.label))) }));
}
export function VesselTable({ rows }) {
    return (_jsxs("div", { className: "overflow-hidden rounded-2xl border border-gray-200 bg-white dark:border-gray-800 dark:bg-white/[0.03]", children: [_jsx("div", { className: "border-b px-5 py-4 font-semibold", children: "20 Data Terbaru" }), _jsxs("table", { className: "w-full text-left text-theme-sm", children: [_jsx("thead", { className: "bg-gray-50 text-gray-500", children: _jsxs("tr", { children: [_jsx("th", { className: "px-5 py-3", children: "Lab No" }), _jsx("th", { className: "px-5 py-3", children: "Vessel" }), _jsx("th", { className: "px-5 py-3", children: "Unit" }), _jsx("th", { className: "px-5 py-3", children: "Sample Date" }), _jsx("th", { className: "px-5 py-3", children: "Condition" }), _jsx("th", { className: "px-5 py-3", children: "Fe" }), _jsx("th", { className: "px-5 py-3", children: "Al" })] }) }), _jsx("tbody", { children: rows.map((r) => (_jsxs("tr", { className: `border-t ${r.condition !== 'NORMAL' ? 'bg-red-50' : ''}`, children: [_jsx("td", { className: "px-5 py-3", children: r.lab_no }), _jsx("td", { className: "px-5 py-3", children: r.vesselid }), _jsx("td", { className: "px-5 py-3", children: r.unit_id }), _jsx("td", { className: "px-5 py-3", children: r.sample_date }), _jsx("td", { className: "px-5 py-3", children: _jsx("span", { className: `rounded-full px-2 py-1 text-theme-xs ${r.condition === 'NORMAL' ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'}`, children: r.condition }) }), _jsx("td", { className: "px-5 py-3", children: r.fe }), _jsx("td", { className: "px-5 py-3", children: r.al })] }, r.lab_no))) })] })] }));
}
export function Trend({ rows }) {
    const pts = [...rows].reverse();
    if (pts.length < 2)
        return null;
    const vals = pts.map((r) => Number(r.fe ?? 0));
    const max = Math.max(...vals, 1);
    const path = vals.map((v, i) => `${(i / (vals.length - 1)) * 300},${60 - (v / max) * 55}`).join(' L');
    return (_jsxs("div", { className: "rounded-2xl border border-gray-200 bg-white p-5 dark:border-gray-800 dark:bg-white/[0.03]", children: [_jsx("p", { className: "font-semibold", children: "Tren Fe (kiri = lama, siap ganti ApexCharts)" }), _jsx("svg", { width: "320", height: "70", className: "mt-2 border border-gray-200", children: _jsx("polyline", { points: path, fill: "none", stroke: "#465fff", strokeWidth: "2" }) })] }));
}
