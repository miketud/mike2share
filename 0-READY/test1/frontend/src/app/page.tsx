'use client';

import { useState } from 'react';

export default function LandingPage() {
  const [showInfo, setShowInfo] = useState(false);
  const [readmeContent, setReadmeContent] = useState('');
  const [loading, setLoading] = useState(false);

  const toggleInfo = async () => {
    // If we are about to show the info and README hasn't been loaded yet, fetch it
    if (!showInfo && readmeContent === '') {
      setLoading(true);
      try {
        const res = await fetch('/README.md');
        const text = await res.text();
        setReadmeContent(text);
      } catch (err) {
        console.error('Failed to load README.md', err);
        setReadmeContent('Unable to load README from /frontend/public/');
      }
      setLoading(false);
    }
    setShowInfo(!showInfo);
  };

  return (
    <div
      style={{
        minHeight: '100vh',
        background: '#ffffff',
        display: 'flex',
        flexDirection: 'column',
      }}
    >
      {/* Header */}
      <header
        style={{
          width: '100%',
          background: '#91cdc4',
          color: '#000000',
          padding: '1rem 2rem',
          borderBottom: '4px solid #000000',
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          fontSize: '1.5rem',
          fontWeight: 600,
        }}
      >
        <div>Next.js/TypeScript + Python Bootstrap</div>
        <button
          onClick={toggleInfo}
          style={{
            background: '#ffffff',
            color: '#000000',
            border: '2px solid #000000',
            padding: '0.5rem 1rem',
            borderRadius: '4px',
            fontSize: '1rem',
            cursor: 'pointer',
          }}
        >
          {loading ? 'Loading...' : showInfo ? 'Hide README' : 'README'}
        </button>
      </header>

      {/* README Section */}
      {showInfo && (
        <section
          style={{
            maxWidth: '80%',
            width: '100%',
            padding: '2rem',
            background: '#ffffff',
          }}
        >
          <div
            style={{
              color: '#334155',
              whiteSpace: 'pre-wrap',
              fontFamily: 'monospace',
              lineHeight: '1.6',
            }}
          >
            {readmeContent || 'No content available'}
          </div>
        </section>
      )}
    </div>
  );
}
