import React, { ReactNode, useEffect, useState } from 'react';
import http from '@/api/http';

interface LockGateProps {
    serverId: string;
    children: ReactNode;
}

interface LockStatus {
    locked: boolean;
}

const getStatus = async (serverId: string): Promise<LockStatus> => {
    const identifier = String(serverId || '').trim();

    if (!identifier) {
        console.error('[ServerLock] Server ID kosong.');
        return { locked: false };
    }

    const url = `/api/client/extensions/serverlock/status/${encodeURIComponent(identifier)}`;

    try {
        const response = await http.get(url);

        return {
            locked: response.status === 200 && response.data?.locked === true,
        };
    } catch (error) {
        console.error('[ServerLock] STATUS ERROR:', {
            serverId: identifier,
            error,
        });

        // Kalau status gagal, JANGAN mengunci server.
        return { locked: false };
    }
};

const verifyPassword = async (serverId: string, password: string): Promise<boolean> => {
    const identifier = String(serverId || '').trim();

    try {
        const response = await http.post(
            `/api/client/extensions/serverlock/verify/${encodeURIComponent(identifier)}`,
            {
                password,
            }
        );

        return response.status === 200 && response.data?.valid === true;
    } catch (error) {
        console.error('[ServerLock] VERIFY ERROR:', error);
        return false;
    }
};

/**
 * Ikon gembok, murni SVG (bukan emoji) supaya konsisten tampilannya
 * di semua OS/browser dan bisa diberi efek glow lewat CSS filter.
 */
const LockIcon = () => (
    <svg
        width="56"
        height="56"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        style={{
            filter: 'drop-shadow(0 0 10px rgba(255,255,255,.55))',
        }}
    >
        <rect
            x="5"
            y="11"
            width="14"
            height="10"
            rx="2"
            stroke="#ffffff"
            strokeWidth="1.6"
        />
        <path
            d="M8 11V7a4 4 0 0 1 8 0v4"
            stroke="#ffffff"
            strokeWidth="1.6"
            strokeLinecap="round"
        />
        <circle cx="12" cy="16" r="1.6" fill="#ffffff" />
        <path
            d="M12 17.6V19"
            stroke="#ffffff"
            strokeWidth="1.6"
            strokeLinecap="round"
        />
    </svg>
);

export default ({ serverId, children }: LockGateProps) => {
    const [checking, setChecking] = useState(true);
    const [locked, setLocked] = useState(false);
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [submitting, setSubmitting] = useState(false);

    useEffect(() => {
        let cancelled = false;

        const check = async () => {
            setChecking(true);
            setLocked(false);
            setError('');
            setPassword('');

            const result = await getStatus(serverId);

            if (cancelled) return;

            setLocked(result.locked);
            setChecking(false);
        };

        check();

        return () => {
            cancelled = true;
        };
    }, [serverId]);

    const submit = async () => {
        if (!password || submitting) return;

        setSubmitting(true);
        setError('');

        const valid = await verifyPassword(serverId, password);

        if (valid) {
            setLocked(false);
            setPassword('');
            setError('');
        } else {
            setError('Password salah.');
        }

        setSubmitting(false);
    };

    if (checking) {
        return (
            <div
                style={{
                    minHeight: '60vh',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    color: '#aaa',
                }}
            >
                Memeriksa status server...
            </div>
        );
    }

    if (!locked) {
        return <>{children}</>;
    }

    return (
        <div
            style={{
                minHeight: '70vh',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                padding: '24px',
                boxSizing: 'border-box',
            }}
        >
            <div
                style={{
                    width: '100%',
                    maxWidth: '460px',
                    background: '#111',
                    border: '1px solid #333',
                    borderRadius: '12px',
                    padding: '32px',
                    boxSizing: 'border-box',
                    textAlign: 'center',
                    color: '#fff',
                    boxShadow: '0 20px 60px rgba(0,0,0,.7)',
                }}
            >
                <div style={{ marginBottom: '14px' }}>
                    <LockIcon />
                </div>

                <h2
                    style={{
                        margin: '0 0 14px',
                        fontSize: '22px',
                    }}
                >
                    Server Terkunci
                </h2>

                {/* ==== WARNING PRIVASI ==== */}
                <div
                    style={{
                        marginBottom: '20px',
                        padding: '14px 16px',
                        borderRadius: '10px',
                        border: '1px solid rgba(255,45,45,.55)',
                        background: 'rgba(255,45,45,.08)',
                    }}
                >
                    <p
                        style={{
                            margin: '0 0 6px',
                            fontSize: '15px',
                            fontWeight: 800,
                            letterSpacing: '.3px',
                            color: '#ff3b3b',
                            textShadow:
                                '0 0 6px rgba(255,255,255,.85), 0 0 14px rgba(255,59,59,.65)',
                        }}
                    >
                        STOP RUSUH. STOP INTIP SERVER ORANG.
                    </p>
                    <p
                        style={{
                            margin: 0,
                            fontSize: '13px',
                            fontWeight: 700,
                            color: '#ff6b6b',
                            textShadow:
                                '0 0 5px rgba(255,255,255,.7), 0 0 10px rgba(255,59,59,.5)',
                        }}
                    >
                        Server orang lain bukan hak kamu untuk kamu akses maupun lihat.
                    </p>
                </div>

                <p
                    style={{
                        color: '#aaa',
                        margin: '0 0 18px',
                        fontSize: '13.5px',
                        lineHeight: 1.5,
                    }}
                >
                    Masukkan password hash kamu jika server ini{' '}
                    <span style={{ color: '#fff', fontWeight: 700 }}>MILIK KAMU</span>.
                </p>

                <input
                    type="password"
                    value={password}
                    autoFocus
                    disabled={submitting}
                    onChange={(e) => setPassword(e.target.value)}
                    onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                            submit();
                        }
                    }}
                    placeholder="Password server"
                    style={{
                        width: '100%',
                        boxSizing: 'border-box',
                        padding: '12px 14px',
                        borderRadius: '8px',
                        border: '1px solid #444',
                        background: '#080808',
                        color: '#fff',
                        outline: 'none',
                        fontSize: '15px',
                        textAlign: 'center',
                        marginBottom: '12px',
                    }}
                />

                {error && (
                    <div
                        style={{
                            color: '#ff6b6b',
                            fontSize: '13px',
                            marginBottom: '12px',
                            fontWeight: 600,
                        }}
                    >
                        {error}
                    </div>
                )}

                <button
                    type="button"
                    onClick={submit}
                    disabled={submitting || !password}
                    style={{
                        width: '100%',
                        padding: '12px 16px',
                        borderRadius: '8px',
                        border: 'none',
                        background:
                            submitting || !password ? '#555' : '#fff',
                        color: '#000',
                        fontWeight: 700,
                        fontSize: '14px',
                        cursor:
                            submitting || !password
                                ? 'not-allowed'
                                : 'pointer',
                    }}
                >
                    {submitting ? 'Memeriksa...' : 'Buka Server'}
                </button>
            </div>
        </div>
    );
};
