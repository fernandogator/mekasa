/**
 * Superdesign mockup.
 * Spec: family members | Design Artifact: design/mockups/FamilyMembers.jsx
 * Preview: https://p.superdesign.dev/draft/248f70a0-c51e-430f-9a3c-ed7d25f68606
 * Not application code. Do not ship.
 */
export default function FamilyMembers() {
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
    <div className="sage-blob" style={{ viewTransitionName: "sage-blob" }}></div>
    
    {/* Header */}
    <header className="shrink-0 pt-14 px-6 z-10" style={{ viewTransitionName: "main-content" }}>
      <div className="flex justify-between items-start">
        <div>
          <h1 className="text-3xl font-black text-brand leading-none mb-1">The Rivas House</h1>
          <p className="text-[12px] font-bold uppercase tracking-[0.1em] text-muted">You · Admin</p>
        </div>
        <a href="#settings" className="w-10 h-10 rounded-full bg-surface-elevated shadow-sm flex items-center justify-center border border-muted">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/></svg>
        </a>
      </div>
    </header>

    {/* Main Content */}
    <main className="flex-1 overflow-y-auto px-6 pt-8 pb-32 z-10 space-y-6" style={{ viewTransitionName: "main-content" }}>
      
      {/* People List */}
      <div className="bg-surface-elevated rounded-[32px] p-2 shadow-[0_20px_50px_-12px_rgba(0,0,0,0.08)] border border-muted space-y-1">
        
        {/* Member 1: Fern (You) */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
          <div className="w-12 h-12 rounded-full bg-[#eaf1ec] flex items-center justify-center mr-4 shrink-0 overflow-hidden">
             <span className="text-xl font-bold text-[#2f6b4f]">F</span>
          </div>
          <div className="flex-1">
            <p className="font-bold text-[16px]">Fern</p>
            <div className="flex items-center mt-1">
              <span className="px-2 py-0.5 bg-[#f1f4f3] rounded-full text-[10px] font-bold uppercase tracking-wider text-muted">Admin</span>
            </div>
          </div>
          <button className="w-10 h-10 rounded-full flex items-center justify-center text-muted hover:bg-gray-100">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="6" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="18" r="1" fill="currentColor"/></svg>
          </button>
        </div>

        {/* Member 2: Maya */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
          <div className="w-12 h-12 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0 overflow-hidden">
            <span className="text-xl font-bold text-brand">M</span>
          </div>
          <div className="flex-1">
            <p className="font-bold text-[16px]">Maya</p>
            <div className="flex items-center mt-1">
              <span className="px-2 py-0.5 bg-[#f1f4f3] rounded-full text-[10px] font-bold uppercase tracking-wider text-muted">Member</span>
            </div>
          </div>
          <button className="w-10 h-10 rounded-full flex items-center justify-center text-muted hover:bg-gray-100">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="6" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="18" r="1" fill="currentColor"/></svg>
          </button>
        </div>

        {/* Member 3: Luis */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors">
          <div className="w-12 h-12 rounded-full bg-[#f1f4f3] flex items-center justify-center mr-4 shrink-0 overflow-hidden">
             <span className="text-xl font-bold text-brand">L</span>
          </div>
          <div className="flex-1">
            <p className="font-bold text-[16px]">Luis</p>
            <div className="flex items-center mt-1">
              <span className="px-2 py-0.5 bg-[#f1f4f3] rounded-full text-[10px] font-bold uppercase tracking-wider text-muted">Member</span>
            </div>
          </div>
          <button className="w-10 h-10 rounded-full flex items-center justify-center text-muted hover:bg-gray-100">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="6" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="18" r="1" fill="currentColor"/></svg>
          </button>
        </div>

        {/* Member 4: Jordan (Invited) */}
        <div className="flex items-center p-3 rounded-[24px] hover:bg-[#f8f9f8] transition-colors opacity-70">
          <div className="w-12 h-12 rounded-full border-2 border-dashed border-muted flex items-center justify-center mr-4 shrink-0">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="8" r="4"/><path d="M4 20a8 8 0 0 1 16 0"/></svg>
          </div>
          <div className="flex-1">
            <p className="font-bold text-[16px] text-muted">Jordan</p>
            <div className="flex items-center mt-1">
              <span className="px-2 py-0.5 bg-[#fdf0e6] rounded-full text-[10px] font-bold uppercase tracking-wider text-[#c45c12]">Invited</span>
            </div>
          </div>
          <button className="w-10 h-10 rounded-full flex items-center justify-center text-muted hover:bg-gray-100">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><circle cx="12" cy="6" r="1" fill="currentColor"/><circle cx="12" cy="12" r="1" fill="currentColor"/><circle cx="12" cy="18" r="1" fill="currentColor"/></svg>
          </button>
        </div>

      </div>

      {/* Actions */}
      <div className="space-y-4 pt-4">
        <button className="w-full h-[56px] bg-accent text-white font-bold rounded-full shadow-[0_8px_16px_rgba(202,0,19,0.3)] active:scale-95 transition-transform flex items-center justify-center space-x-2">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-5 h-5"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M16 11h6"/></svg>
          <span>Invite someone</span>
        </button>
        
        <button className="w-full h-[56px] bg-white border border-muted text-brand font-bold rounded-full active:scale-95 transition-transform">
          Leave household
        </button>
      </div>

    </main>

    {/* Bottom Navigation (Persistent) */}
    <nav className="absolute bottom-8 left-6 right-6 z-40" style={{ viewTransitionName: "nav" }}>
      <div className="bg-brand h-[64px] rounded-full flex items-center justify-between px-6 shadow-xl relative">
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M3 9.5 12 3l9 6.5V20a1 1 0 0 1-1 1h-5v-6H9v6H4a1 1 0 0 1-1-1z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M8 6h13M8 12h13M8 18h13"/><path d="m3 6 1 1 2-2M3 12l1 1 2-2M3 18l1 1 2-2"/></svg>
        </a>
        
        {/* Spacer for FAB */}
        <div className="w-16"></div>
        
        <a href="#" className="flex flex-col items-center justify-center text-[#b7c6c2] w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M21.21 15.89A10 10 0 1 1 8 2.83"/><path d="M22 12A10 10 0 0 0 12 2v10z"/></svg>
        </a>
        <a href="#" className="flex flex-col items-center justify-center text-white w-12">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87M16 3.13a4 4 0 0 1 0 7.75"/></svg>
        </a>
      </div>
      
      {/* Center Add FAB (Persistent) */}
      <a href="#" className="absolute left-1/2 -top-6 -translate-x-1/2 w-[56px] h-[56px] bg-accent rounded-full flex items-center justify-center text-white shadow-[0_8px_16px_rgba(202,0,19,0.3)] border-[4px] border-[#eeebe3] active:scale-95 transition-transform" style={{ viewTransitionName: "fab" }}>
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" className="w-6 h-6"><path d="M12 5v14M5 12h14"/></svg>
      </a>
    </nav>

  </div>
    </>
  );
}
