import { jsx as _jsx, jsxs as _jsxs } from "react/jsx-runtime";
import { useState } from 'react';
import Layout from './components/Layout';
import LoginPage from './pages/Login';
import { Dashboard, FleetPage, ImportPage } from './pages/Pages';
export default function App() {
    const [authed, setAuthed] = useState(!!localStorage.getItem('mte_token'));
    const [page, setPage] = useState('dashboard');
    if (!authed)
        return _jsx(LoginPage, { onOk: () => setAuthed(true) });
    return (_jsxs(Layout, { page: page, setPage: setPage, onLogout: () => { localStorage.clear(); setAuthed(false); }, children: [(page === 'dashboard' || page === 'vessel') && _jsx(Dashboard, {}), page === 'fleet' && _jsx(FleetPage, {}), page === 'import' && _jsx(ImportPage, {})] }));
}
