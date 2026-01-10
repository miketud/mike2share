"use client";

import { useState } from "react";
import ReactMarkdown from "react-markdown";

export default function Home() {
  const [showReadme, setShowReadme] = useState(false);
  const [readmeContent, setReadmeContent] = useState<string>("");

  const toggleReadme = async () => {
    // If we are about to show the README and it hasn't been loaded yet,
    // fetch it from the project root.
    if (!showReadme && readmeContent === "") {
      try {
        const res = await fetch("/README.md");
        const text = await res.text();
        setReadmeContent(text);
      } catch (err) {
        console.error("Failed to load README.md", err);
        setReadmeContent("Unable to load README.");
      }
    }
    setShowReadme(!showReadme);
  };

  return (
    <div
      style={{
        minHeight: "100vh",
        background: "#f9f9f9", // off‑white background
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
      }}
    >
      {/* Header */}
      <header
        style={{
          width: "100%",
          maxWidth: "48rem",
          background: "#ffffff",
          color: "#000000",
          padding: "1rem 2rem",
          borderBottom: "4px solid #000000", // thick black bottom border
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          fontSize: "1.5rem",
          fontWeight: 600,
        }}
      >
        <div>Next.js/TypeScript + Python Bootstrap</div>
        <button
          onClick={toggleReadme}
          style={{
            background: "#ffffff",
            color: "#000000",
            border: "2px solid #000000",
            padding: "0.5rem 1rem",
            borderRadius: "4px",
            fontSize: "1rem",
            cursor: "pointer",
          }}
        >
          README
        </button>
      </header>

      {/* README content – rendered only when the button is clicked */}
      {showReadme && (
        <section
          style={{
            maxWidth: "48rem",
            width: "100%",
            padding: "1rem 2rem",
            background: "#ffffff",
          }}
        >
          <ReactMarkdown>{readmeContent}</ReactMarkdown>
        </section>
      )}
    </div>
  );
}
