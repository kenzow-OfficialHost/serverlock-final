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

    console.log('[ServerLock] CHECK:', {
        serverId: identifier,
        url,
    });

    try {
        const response = await http.get(url);

        console.log('[ServerLock] RESPONSE:', {
            serverId: identifier,
            status: response.status,
            data: response.data,
        });

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

        console.log('[ServerLock] VERIFY:', {
            serverId: identifier,
            status: response.status,
            data: response.data,
        });

        return response.status === 200 && response.data?.valid === true;
    } catch (error) {
        console.error('[ServerLock] VERIFY ERROR:', error);
        return false;
    }
};

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

            console.log('[ServerLock] CURRENT SERVER:', serverId);

            const result = await getStatus(serverId);

            if (cancelled) return;

            console.log('[ServerLock] FINAL STATE:', {
                serverId,
                locked: result.locked,
            });

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
                    maxWidth: '420px',
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
                <div
                    style={{
                        fontSize: '42px',
                        marginBottom: '12px',
                    }}
                >
                    🔒
                </div>

                <h2
                    style={{
                        margin: '0 0 10px',
                        fontSize: '22px',
                    }}
                >
                    Server Terkunci
                </h2>

                <p
                    style={{
                        color: '#aaa',
                        margin: '0 0 20px',
                        fontSize: '14px',
                    }}
                >
                    Masukkan password untuk mengakses server ini.
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
