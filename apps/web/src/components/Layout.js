import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useState } from 'react';
const MENU = [
    { key: 'dashboard', label: 'Dashboard' },
    { key: 'vessel', label: 'Data Vessel' },
    { key: 'fleet', label: 'Fleet Alert' },
    { key: 'import', label: 'Import Excel' },
];
export default function Layout({ page, setPage, onLogout, children }) {
    const [open, setOpen] = useState(true);
    return (_jsxs("div", { className: "flex h-screen bg-gray-50 font-outfit dark:bg-gray-900", children: [open && (_jsxs("aside", { className: "flex w-72 flex-col border-r border-gray-200 bg-white px-5 dark:border-gray-800 dark:bg-black", children: [_jsx("div", { className: "flex items-center gap-2 pt-8 pb-7", children: _jsx("span", { className: "text-xl font-bold text-brand-600", children: "MTE Oil Lab" }) }), _jsxs("nav", { className: "flex flex-col gap-1", children: [_jsx("p", { className: "mb-4 text-xs uppercase text-gray-400", children: "Menu" }), MENU.map((m) => (_jsx("button", { onClick: () => setPage(m.key), className: `rounded-lg px-3 py-2 text-left text-theme-sm ${page === m.key ? 'bg-brand-50 text-brand-600' : 'text-gray-600 hover:bg-gray-100'}`, children: m.label }, m.key)))] }), _jsx("button", { onClick: onLogout, className: "mt-auto mb-6 rounded-lg border px-3 py-2 text-theme-sm text-gray-600", children: "Logout" })] })), _jsxs("div", { className: "flex flex-1 flex-col", children: [_jsxs("header", { className: "flex items-center gap-2 border-b border-gray-200 bg-white px-6 py-4 dark:border-gray-800 dark:bg-gray-900", children: [_jsx("button", { onClick: () => setOpen(!open), className: "rounded-lg border px-3 py-1 text-gray-500", children: "\u2630" }), _jsx("h1", { className: "text-theme-xl font-semibold", children: "Monitoring Oil Lab" })] }), _jsx("main", { className: "flex-1 overflow-y-auto p-6", children: children })] })] }));
}
