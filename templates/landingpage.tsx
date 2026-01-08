'use client';

import { motion } from 'framer-motion';
import { useEffect, useState } from 'react';

export default function Home() {
    const [theme, setTheme] = useState<'light' | 'dark'>('light');

    useEffect(() => {
        // Check for saved theme preference or default to system preference
        const savedTheme = localStorage.getItem('theme') as 'light' | 'dark' | null;
        const systemTheme = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
        const initialTheme = savedTheme || systemTheme;

        setTheme(initialTheme);
        document.documentElement.setAttribute('data-theme', initialTheme);
    }, []);

    const toggleTheme = () => {
        const newTheme = theme === 'light' ? 'dark' : 'light';
        setTheme(newTheme);
        document.documentElement.setAttribute('data-theme', newTheme);
        localStorage.setItem('theme', newTheme);
    };

    const stackItems = [
        {
            name: 'Next.js v14',
            desc: 'React framework with SSR, SSG, and API routes',
        },
        { name: 'TypeScript v5', desc: 'Static typing for safer code' },
        {
            name: 'FastAPI v0.115',
            desc: 'Async Python web framework with automatic OpenAPI docs',
        },
        {
            name: 'Python v3.12',
            desc: 'Modern language features and improved performance',
        },
        { name: 'PostgreSQL v15', desc: 'ACID-compliant relational database' },
        { name: 'React Query', desc: 'Data-fetching & caching layer' },
        {
            name: 'Axios',
            desc: 'HTTP client with interceptor-based error handling',
        },
    ];

    return (
        <div style={{
            minHeight: '100vh',
            background: 'var(--background)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: '2rem',
            position: 'relative'
        }}>
            {/* Theme Toggle Button */}
            <button
                onClick={toggleTheme}
                style={{
                    position: 'fixed',
                    top: '2rem',
                    right: '2rem',
                    width: '3rem',
                    height: '3rem',
                    borderRadius: '50%',
                    background: 'var(--secondary)',
                    border: '1px solid var(--border)',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontSize: '1.5rem',
                    transition: 'transform 0.2s ease',
                    zIndex: 50
                }}
                onMouseEnter={(e) => e.currentTarget.style.transform = 'scale(1.1)'}
                onMouseLeave={(e) => e.currentTarget.style.transform = 'scale(1)'}
                aria-label="Toggle theme"
            >
                {theme === 'light' ? '🌙' : '☀️'}
            </button>

            <main style={{ maxWidth: '48rem', width: '100%' }}>
                <motion.h1
                    initial={{ opacity: 0, y: -20 }}
                    animate={{ opacity: 1, y: 0 }}
                    transition={{ duration: 0.8, ease: 'easeOut' }}
                    style={{
                        fontSize: 'clamp(2rem, 5vw, 3rem)',
                        fontWeight: 700,
                        color: 'var(--foreground)',
                        marginBottom: '1rem'
                    }}
                >
                    Welcome to the Project Starter Kit
                </motion.h1>

                <motion.p
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: 0.6, delay: 0.3 }}
                    style={{
                        fontSize: '1.125rem',
                        color: 'var(--muted-foreground)',
                        marginBottom: '3rem'
                    }}
                >
                    A full-stack starter built with modern tools
                </motion.p>

                <ul style={{ listStyle: 'none', padding: 0, display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
                    {stackItems.map((item, index) => (
                        <motion.li
                            key={item.name}
                            initial={{ opacity: 0, x: -20 }}
                            animate={{ opacity: 1, x: 0 }}
                            transition={{
                                duration: 0.5,
                                delay: 0.6 + index * 0.15,
                                ease: 'easeOut',
                            }}
                            style={{
                                background: 'var(--card)',
                                borderRadius: 'var(--radius)',
                                padding: '1.5rem',
                                boxShadow: 'var(--shadow-sm)',
                                border: '1px solid var(--border)'
                            }}
                        >
                            <h3 style={{
                                fontSize: '1.25rem',
                                fontWeight: 600,
                                color: 'var(--foreground)',
                                marginBottom: '0.25rem'
                            }}>
                                {item.name}
                            </h3>
                            <p style={{ color: 'var(--muted-foreground)', margin: 0 }}>{item.desc}</p>
                        </motion.li>
                    ))}
                </ul>

                <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 1 }}
                    transition={{ duration: 0.6, delay: 0.6 + stackItems.length * 0.15 }}
                    style={{ marginTop: '3rem', textAlign: 'center' }}
                >
                    <a
                        href="https://github.com"
                        target="_blank"
                        rel="noopener noreferrer"
                        style={{
                            display: 'inline-block',
                            padding: '0.75rem 2rem',
                            background: 'var(--primary)',
                            color: 'var(--primary-foreground)',
                            borderRadius: 'var(--radius)',
                            fontWeight: 500,
                            transition: 'opacity 0.15s ease'
                        }}
                    >
                        View Repository
                    </a>
                </motion.div>
            </main>
        </div>
    );
}