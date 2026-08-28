import React, { useEffect, useState } from 'react';

// Ambil uuidShort server dari URL, contoh: /server/a39b9586/...
function getServerIdFromUrl(): string | null {
    const match = window.location.pathname.match(/\/server\/([a-zA-Z0-9]+)/);
    return match ? match[1] : null;
}

function getXsrfToken(): string {
    const match = document.cookie.match(/XSRF-TOKEN=([^;]+)/);
    return match ? decodeURIComponent(match[1]) : '';
}

async function apiPost(path: string, body: any) {
    const res = await fetch(`/api/client/extensions/serverlock/${path}`, {
        method: 'POST',
        credentials: 'include',
        headers: {
            'Content-Type': 'application/json',
            'X-XSRF-TOKEN': getXsrfToken(),
        },
        body: JSON.stringify(body),
    });
    return { ok: res.ok, data: await res.json().catch(() => ({})) };
}

async function apiGet(path: string) {
    const res = await fetch(`/api/client/extensions/serverlock/${path}`, {
        method: 'GET',
        credentials: 'include',
    });
    return { ok: res.ok, data: await res.json().catch(() => ({})) };
}

export default () => {
    const serverId = getServerIdFromUrl();
    const [checking, setChecking] = useState(true);
    const [locked, setLocked] = useState(false);
    const [unlocked, setUnlocked] = useState(false);
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        if (!serverId) return;

        const sessionKey = `serverlock:${serverId}`;
        if (sessionStorage.getItem(sessionKey) === 'unlocked') {
            setUnlocked(true);
            setChecking(false);
            return;
        }

        apiGet(`status/${serverId}`).then(({ ok, data }) => {
            if (ok && data.locked) {
                setLocked(true);
            }
            setChecking(false);
        });
    }, [serverId]);

    const submit = async () => {
        if (!serverId || !password) return;
        setSubmitting(true);
        setError('');

        const { ok, data } = await apiPost(`verify/${serverId}`, { password });

        if (ok && data.valid) {
            sessionStorage.setItem(`serverlock:${serverId}`, 'unlocked');
            setUnlocked(true);
        } else {
            setError('Password salah. Coba lagi.');
        }
        setSubmitting(false);
    };

    if (checking || !locked || unlocked) {
        return null;
    }

    return (
        <div
            style={{
                position: 'fixed',
                inset: 0,
                zIndex: 9999,
                background: 'rgba(0,0,0,0.92)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                flexDirection: 'column',
                gap: '1rem',
                color: '#fff',
                fontFamily: 'inherit',
            }}
        >
            <p style={{ fontSize: '1.1rem', fontWeight: 600 }}>
                Server ini dikunci. Masukkan password untuk melanjutkan.
            </p>
            <input
                type="password"
                value={password}
                autoFocus
                onChange={(e) => setPassword(e.target.value)}
                onKeyDown={(e) => e.key === 'Enter' && submit()}
                placeholder="Password server"
                style={{
                    padding: '0.6rem 1rem',
                    borderRadius: '6px',
                    border: '1px solid #444',
                    background: '#111',
                    color: '#fff',
                    width: '260px',
                    textAlign: 'center',
                }}
            />
            {error && <p style={{ color: '#ff6b6b', margin: 0 }}>{error}</p>}
            <button
                onClick={submit}
                disabled={submitting}
                style={{
                    padding: '0.55rem 1.4rem',
                    borderRadius: '6px',
                    border: 'none',
                    background: '#fff',
                    color: '#000',
                    fontWeight: 600,
                    cursor: 'pointer',
                }}
            >
                {submitting ? 'Memeriksa...' : 'Buka'}
            </button>
        </div>
    );
};
