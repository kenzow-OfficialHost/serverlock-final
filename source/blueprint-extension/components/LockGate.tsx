import React, { ReactNode, useEffect, useRef, useState } from 'react';
import http from '@/api/http';

interface LockGateProps {
    serverId: string;
    children: ReactNode;
}

interface StatusResult {
    locked: boolean;
    alreadyUnlocked: boolean;
}

interface VerifyResult {
    valid: boolean;
    lockedOut?: boolean;
    retryAfter?: number;
    message?: string;
}

const getStatus = async (serverId: string): Promise<StatusResult> => {
    const identifier = String(serverId || '').trim();

    if (!identifier) {
        console.error('[ServerLock] Server ID kosong.');
        return { locked: false, alreadyUnlocked: false };
    }

    const url = `/api/client/extensions/serverlock/status/${encodeURIComponent(identifier)}`;

    try {
        const response = await http.get(url);

        return {
            locked: response.status === 200 && response.data?.locked === true,
            alreadyUnlocked: response.data?.already_unlocked === true,
        };
    } catch (error) {
        console.error('[ServerLock] STATUS ERROR:', { serverId: identifier, error });

        // Kalau status gagal, JANGAN mengunci server.
        return { locked: false, alreadyUnlocked: false };
    }
};

const verifyPassword = async (serverId: string, password: string): Promise<VerifyResult> => {
    const identifier = String(serverId || '').trim();

    try {
        const response = await http.post(
            `/api/client/extensions/serverlock/verify/${encodeURIComponent(identifier)}`,
            { password }
        );

        return { valid: response.status === 200 && response.data?.valid === true };
    } catch (error: any) {
        const data = error?.response?.data;

        if (error?.response?.status === 429 && data) {
            return {
                valid: false,
                lockedOut: true,
                retryAfter: Number(data.retry_after) || 60,
                message: data.message,
            };
        }

        console.error('[ServerLock] VERIFY ERROR:', error);
        return { valid: false };
    }
};

/**
 * Ikon gembok, murni SVG (bukan emoji) supaya konsisten di semua
 * OS/browser dan bisa dikasih efek glow lewat CSS filter + animasi pulse.
 */
const LockIcon = ({ pulsing = true }: { pulsing?: boolean }) => (
    <svg
        width="60"
        height="60"
        viewBox="0 0 24 24"
        fill="none"
        xmlns="http://www.w3.org/2000/svg"
        style={{
            filter: 'drop-shadow(0 0 12px rgba(139,92,246,.65))',
            animation: pulsing ? 'serverlock-pulse 2.4s ease-in-out infinite' : undefined,
        }}
    >
        <rect x="5" y="11" width="14" height="10" rx="2" stroke="#c4b5fd" strokeWidth="1.6" />
        <path d="M8 11V7a4 4 0 0 1 8 0v4" stroke="#c4b5fd" strokeWidth="1.6" strokeLinecap="round" />
        <circle cx="12" cy="16" r="1.6" fill="#a78bfa" />
        <path d="M12 17.6V19" stroke="#c4b5fd" strokeWidth="1.6" strokeLinecap="round" />
    </svg>
);

const formatRetry = (seconds: number): string => {
    if (seconds < 60) return `${seconds} detik`;
    const m = Math.floor(seconds / 60);
    const s = seconds % 60;
    return s > 0 ? `${m} menit ${s} detik` : `${m} menit`;
};

export default ({ serverId, children }: LockGateProps) => {
    const [checking, setChecking] = useState(true);
    const [locked, setLocked] = useState(false);
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [submitting, setSubmitting] = useState(false);
    const [lockedOutUntilSeconds, setLockedOutUntilSeconds] = useState<number | null>(null);

    const countdownRef = useRef<ReturnType<typeof setInterval> | null>(null);

    useEffect(() => {
        let cancelled = false;

        const check = async () => {
            setChecking(true);
            setError('');
            setPassword('');
            setLockedOutUntilSeconds(null);

            const result = await getStatus(serverId);

            if (cancelled) return;

            // Kalau backend bilang grant unlock user ini masih berlaku,
            // langsung tampilin konten -- nggak perlu ngetik password lagi
            // tiap kali pindah tab/refresh (grant-nya disimpan di server,
            // bukan di React state doang).
            setLocked(result.locked && !result.alreadyUnlocked);
            setChecking(false);
        };

        check();

        return () => {
            cancelled = true;
            if (countdownRef.current) clearInterval(countdownRef.current);
        };
    }, [serverId]);

    const startCountdown = (seconds: number) => {
        setLockedOutUntilSeconds(seconds);
        if (countdownRef.current) clearInterval(countdownRef.current);

        countdownRef.current = setInterval(() => {
            setLockedOutUntilSeconds((prev) => {
                if (prev === null || prev <= 1) {
                    if (countdownRef.current) clearInterval(countdownRef.current);
                    return null;
                }
                return prev - 1;
            });
        }, 1000);
    };

    const submit = async () => {
        if (!password || submitting || lockedOutUntilSeconds) return;

        setSubmitting(true);
        setError('');

        const result = await verifyPassword(serverId, password);

        if (result.valid) {
            setLocked(false);
            setPassword('');
            setError('');
        } else if (result.lockedOut && result.retryAfter) {
            setError(result.message || 'Terlalu banyak percobaan salah.');
            startCountdown(result.retryAfter);
        } else {
            setError('Password salah.');
        }

        setSubmitting(false);
    };

    if (checking) {
        return (
            <div style={styles.centerWrap}>
                <div style={{ ...styles.spinnerText }}>
                    <span style={styles.spinnerDot} /> Memeriksa status server...
                </div>
                <style>{keyframes}</style>
            </div>
        );
    }

    if (!locked) {
        return <>{children}</>;
    }

    const isLockedOut = !!lockedOutUntilSeconds;

    return (
        <div style={styles.centerWrap}>
            <style>{keyframes}</style>

            <div style={styles.card}>
                <div style={styles.cardGlow} />

                <div style={{ marginBottom: '16px', position: 'relative', zIndex: 1 }}>
                    <LockIcon pulsing={!isLockedOut} />
                </div>

                <h2 style={styles.title}>Server Terkunci</h2>

                <div style={styles.warningBox}>
                    <p style={styles.warningTitle}>STOP RUSUH. STOP INTIP SERVER ORANG.</p>
                    <p style={styles.warningSub}>Server orang lain bukan hak kamu untuk kamu akses maupun lihat.</p>
                </div>

                <p style={styles.helperText}>
                    Masukkan password server ini jika server ini{' '}
                    <span style={{ color: '#f3f0ff', fontWeight: 700 }}>MILIK KAMU</span>.
                </p>

                <input
                    type="password"
                    value={password}
                    autoFocus
                    disabled={submitting || isLockedOut}
                    onChange={(e) => setPassword(e.target.value)}
                    onKeyDown={(e) => {
                        if (e.key === 'Enter') submit();
                    }}
                    placeholder="Password server"
                    style={{
                        ...styles.input,
                        opacity: isLockedOut ? 0.5 : 1,
                        cursor: isLockedOut ? 'not-allowed' : 'text',
                    }}
                />

                {error && (
                    <div style={styles.errorBox}>
                        {error}
                        {isLockedOut && (
                            <div style={styles.errorCountdown}>
                                Coba lagi dalam <strong>{formatRetry(lockedOutUntilSeconds!)}</strong>
                            </div>
                        )}
                    </div>
                )}

                <button
                    type="button"
                    onClick={submit}
                    disabled={submitting || !password || isLockedOut}
                    style={{
                        ...styles.button,
                        ...(submitting || !password || isLockedOut ? styles.buttonDisabled : styles.buttonActive),
                    }}
                >
                    {isLockedOut
                        ? `Terkunci sementara (${formatRetry(lockedOutUntilSeconds!)})`
                        : submitting
                        ? 'Memeriksa...'
                        : 'Buka Server'}
                </button>

                <p style={styles.footer}>🔒 Diamankan oleh ServerLock — dibikin sama Kenzo</p>
            </div>
        </div>
    );
};

const keyframes = `
@keyframes serverlock-pulse {
    0%, 100% { filter: drop-shadow(0 0 12px rgba(139,92,246,.65)); transform: scale(1); }
    50% { filter: drop-shadow(0 0 22px rgba(168,85,247,.9)); transform: scale(1.05); }
}
@keyframes serverlock-fade-in {
    from { opacity: 0; transform: translateY(6px); }
    to { opacity: 1; transform: translateY(0); }
}
@keyframes serverlock-spin-dot {
    0%, 100% { opacity: .3; }
    50% { opacity: 1; }
}
`;

const styles: Record<string, React.CSSProperties> = {
    centerWrap: {
        minHeight: '100vh',
        width: '100%',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px',
        boxSizing: 'border-box',
        background:
            'radial-gradient(circle at 50% 0%, rgba(88,28,135,.35), transparent 60%), linear-gradient(180deg, #0a0710 0%, #050308 100%)',
    },
    spinnerText: {
        color: '#a78bfa',
        fontSize: '14px',
        fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
    },
    spinnerDot: {
        width: '8px',
        height: '8px',
        borderRadius: '50%',
        background: '#a78bfa',
        animation: 'serverlock-spin-dot 1s ease-in-out infinite',
    },
    card: {
        position: 'relative',
        width: '100%',
        maxWidth: '440px',
        background: 'linear-gradient(180deg, #12101c 0%, #0c0a14 100%)',
        border: '1px solid rgba(139,92,246,.35)',
        borderRadius: '16px',
        padding: '36px 32px',
        boxSizing: 'border-box',
        textAlign: 'center',
        color: '#fff',
        boxShadow: '0 24px 70px rgba(0,0,0,.75), 0 0 0 1px rgba(139,92,246,.08) inset',
        overflow: 'hidden',
        animation: 'serverlock-fade-in .35s ease-out',
    },
    cardGlow: {
        position: 'absolute',
        top: '-60%',
        left: '50%',
        transform: 'translateX(-50%)',
        width: '260px',
        height: '260px',
        background: 'radial-gradient(circle, rgba(139,92,246,.28), transparent 70%)',
        pointerEvents: 'none',
    },
    title: {
        margin: '0 0 16px',
        fontSize: '22px',
        fontWeight: 800,
        letterSpacing: '.2px',
        position: 'relative',
        zIndex: 1,
        background: 'linear-gradient(90deg, #e9d5ff, #c4b5fd)',
        WebkitBackgroundClip: 'text',
        WebkitTextFillColor: 'transparent',
    },
    warningBox: {
        position: 'relative',
        zIndex: 1,
        marginBottom: '20px',
        padding: '14px 16px',
        borderRadius: '10px',
        border: '1px solid rgba(255,80,80,.55)',
        background: 'rgba(255,45,45,.12)',
    },
    warningTitle: {
        margin: '0 0 6px',
        fontSize: '14.5px',
        fontWeight: 800,
        letterSpacing: '.3px',
        lineHeight: 1.4,
        color: '#ffb3b3',
        textShadow: 'none',
    },
    warningSub: {
        margin: 0,
        fontSize: '13px',
        fontWeight: 500,
        lineHeight: 1.5,
        color: '#e8b4b4',
    },
    helperText: {
        position: 'relative',
        zIndex: 1,
        color: '#a1a1aa',
        margin: '0 0 18px',
        fontSize: '13.5px',
        lineHeight: 1.5,
    },
    input: {
        position: 'relative',
        zIndex: 1,
        width: '100%',
        boxSizing: 'border-box',
        padding: '13px 14px',
        borderRadius: '10px',
        border: '1px solid rgba(139,92,246,.35)',
        background: '#0a0810',
        color: '#f4f4f5',
        outline: 'none',
        fontSize: '15px',
        textAlign: 'center',
        marginBottom: '12px',
        fontFamily: "'JetBrains Mono', 'Fira Code', monospace",
        letterSpacing: '2px',
    },
    errorBox: {
        position: 'relative',
        zIndex: 1,
        color: '#ff8a8a',
        fontSize: '13px',
        marginBottom: '14px',
        fontWeight: 600,
        lineHeight: 1.5,
    },
    errorCountdown: {
        marginTop: '4px',
        color: '#d4d4d8',
        fontSize: '12px',
        fontWeight: 500,
    },
    button: {
        position: 'relative',
        zIndex: 1,
        width: '100%',
        padding: '13px 16px',
        borderRadius: '10px',
        border: 'none',
        fontWeight: 700,
        fontSize: '14px',
        transition: 'all .15s ease',
    },
    buttonActive: {
        background: 'linear-gradient(90deg, #7c3aed, #a855f7)',
        color: '#fff',
        cursor: 'pointer',
        boxShadow: '0 8px 22px rgba(124,58,237,.45)',
    },
    buttonDisabled: {
        background: '#2a2735',
        color: '#71717a',
        cursor: 'not-allowed',
        boxShadow: 'none',
    },
    footer: {
        position: 'relative',
        zIndex: 1,
        margin: '18px 0 0',
        fontSize: '11px',
        color: '#52525b',
        letterSpacing: '.2px',
    },
};
