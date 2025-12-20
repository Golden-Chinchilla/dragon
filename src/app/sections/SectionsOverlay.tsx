import { SECTIONS } from "../../config/sections";

const ALIGN_CLASS: Record<string, string> = {
  left: "items-center justify-start text-left",
  center: "items-center justify-center text-center",
  right: "items-center justify-end text-right",
};

export default function SectionsOverlay() {
  return (
    <div className="w-screen">
      {SECTIONS.map((section) => (
        <section
          key={section.id}
          className={`flex h-screen w-screen px-[10vw] ${ALIGN_CLASS[section.align]}`}
        >
          <div className="pointer-events-none max-w-xl space-y-3 text-slate-100">
            <p className="text-xs uppercase tracking-[0.3em] text-slate-400">
              {section.title}
            </p>
            <h2 className="text-3xl font-semibold">{section.title}</h2>
            <p className="text-base text-slate-200">{section.body}</p>
          </div>
        </section>
      ))}
    </div>
  );
}
