/**
 * Superdesign mockup.
 * Spec: onboarding household setup | Design Artifact: design/mockups/OnboardingHouseholdSetup.jsx
 * Preview: https://p.superdesign.dev/draft/cf8659c3-ef2d-4f9c-b097-f7774783a2f3
 * Not application code. Do not ship.
 */
export default function OnboardingHouseholdSetup() {
  return (
    <>
      <style>{`  @import url('https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800;900&display=swap');
  :root {
    --color-brand: #171e19;
    --color-brand-muted: #b7c6c2;
    --color-surface: #eeebe3;
    --color-surface-elevated: #ffffff;
    --color-text: #171e19;
    --color-text-muted: #6d7a76;
    --color-accent: #ca0013;
    --color-danger: #ca0013;
    --color-success: #2f6b4f;
    --color-warning: #c45c12;
    --color-overlay: rgba(183, 198, 194, 0.20);
  }
  .mekasa-screen {
    font-family: Nunito, sans-serif;
    background-color: var(--color-surface);
    color: var(--color-text);
  }
  .mekasa-screen .text-brand { color: var(--color-brand); }
  .mekasa-screen .text-muted { color: var(--color-text-muted); }
  .mekasa-screen .bg-brand { background-color: var(--color-brand); }
  .mekasa-screen .bg-accent { background-color: var(--color-accent); }
  .mekasa-screen .bg-surface-elevated { background-color: var(--color-surface-elevated); }
  .mekasa-screen .border-muted { border-color: rgba(183, 198, 194, 0.3); }
  .mekasa-screen .sage-blob {
    position: absolute;
    top: -50px;
    right: -50px;
    width: 300px;
    height: 300px;
    border-radius: 50%;
    background: var(--color-overlay);
    filter: blur(40px);
    z-index: 0;
    pointer-events: none;
  }
  .mekasa-screen .store-checkbox {
    appearance: none;
    width: 24px;
    height: 24px;
    border: 2px solid var(--color-brand-muted);
    border-radius: 50%;
    outline: none;
    cursor: pointer;
    position: relative;
  }
  .mekasa-screen .store-checkbox:checked {
    background-color: var(--color-accent);
    border-color: var(--color-accent);
  }
  .mekasa-screen .checkbox-custom {
    width: 40px;
    height: 40px;
    border-radius: 50%;
    border: 2px solid var(--color-brand-muted);
    display: flex;
    align-items: center;
    justify-content: center;
  }
  .mekasa-screen .checkbox-custom.checked {
    background-color: var(--color-accent);
    border-color: var(--color-accent);
    color: white;
  }`}</style>
      <div className="mekasa-screen w-full h-screen flex flex-col relative overflow-hidden bg-[#eeebe3]">
    <div className="sage-blob"></div>
    
    {/* Onboarding Header */}
    <header className="shrink-0 pt-14 px-6 z-10 flex flex-col items-center">
      <div className="text-[10px] font-bold uppercase tracking-[0.12em] text-[#6d7a76] mb-2">2 / 6</div>
      <div className="text-3xl font-black text-[#171e19] tracking-tight">Mekasa</div>
    </header>

    {/* Main Content */}
    <main className="flex-1 overflow-y-auto px-6 pt-12 pb-32 z-10 flex flex-col items-center text-center" style={{ viewTransitionName: "main-content" }}>
      
      <h1 className="text-[32px] font-black text-[#171e19] leading-tight mb-8">
        Name this house.
      </h1>

      {/* Photo Drop Zone */}
      <div className="relative w-32 h-32 mb-10">
        <div className="w-full h-full rounded-full bg-white border-2 border-dashed border-[#b7c6c2] flex flex-col items-center justify-center text-[#171e19] shadow-sm">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 9.5 12 3l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
          <span className="text-[10px] font-bold uppercase tracking-wider text-[#6d7a76]">Add Photo</span>
        </div>
        <button className="absolute bottom-0 right-0 w-8 h-8 rounded-full bg-[#171e19] text-white flex items-center justify-center shadow-md">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-4 h-4"><path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"/><circle cx="12" cy="13" r="4"/></svg>
        </button>
      </div>

      {/* Form Input */}
      <div className="w-full max-w-sm flex flex-col items-start">
        <label className="text-[12px] font-bold uppercase tracking-[0.1em] text-[#6d7a76] mb-2 ml-4">Household Name</label>
        <input type="text" value="The Rivas House" className="w-full bg-white text-[#171e19] text-[20px] font-extrabold rounded-[24px] px-6 py-4 shadow-sm border border-[rgba(183,198,194,0.3)] focus:outline-none focus:ring-2 focus:ring-[#ca0013] transition-all" />
        <p className="text-[14px] font-semibold text-[#6d7a76] mt-4 text-left ml-4 leading-relaxed">
          You're the admin. You can invite people next.
        </p>
      </div>

    </main>

    {/* Sticky Bottom CTA */}
    <div className="absolute bottom-0 left-0 right-0 p-6 pb-8 z-40 bg-gradient-to-t from-[#eeebe3] via-[#eeebe3] to-transparent">
      <a href="#" className="w-full h-[56px] bg-[#ca0013] text-white text-[18px] font-extrabold rounded-[24px] flex items-center justify-center shadow-[0_8px_20px_rgba(202,0,19,0.25)] active:scale-95 transition-transform">
        Continue
      </a>
    </div>

  </div>
    </>
  );
}
