export type SectionAlignment = "left" | "right" | "center";

export type SectionAnimationSpec = {
  loopLabel?: string;
  oneShotLabels?: string[];
  sequenceLabels?: string[];
};

export type SectionConfig = {
  id: string;
  title: string;
  body: string;
  align: SectionAlignment;
  start: number;
  end: number;
  animation: SectionAnimationSpec;
};

export const SECTIONS: SectionConfig[] = [
  {
    id: "section-01",
    title: "Section 01",
    body: "Placeholder copy for the opening scene.",
    align: "center",
    start: 0,
    end: 0.15,
    animation: {
      loopLabel: "Resting",
      oneShotLabels: ["Battle Stance"],
    },
  },
  {
    id: "section-02",
    title: "Section 02",
    body: "Placeholder copy for the awakening.",
    align: "right",
    start: 0.15,
    end: 0.3,
    animation: {
      loopLabel: "Battle Stance",
      oneShotLabels: ["Head-Up Roar I"],
    },
  },
  {
    id: "section-03",
    title: "Section 03",
    body: "Placeholder copy for the threat display.",
    align: "left",
    start: 0.3,
    end: 0.5,
    animation: {
      loopLabel: "Crouched Sneak",
      oneShotLabels: ["Grounded Roar", "Head-Up Roar II"],
    },
  },
  {
    id: "section-04",
    title: "Section 04",
    body: "Placeholder copy for the power reveal.",
    align: "center",
    start: 0.5,
    end: 0.7,
    animation: {
      loopLabel: "Forward March",
      sequenceLabels: ["Wing Spread Roar", "Wing-Braced Double Roar"],
      oneShotLabels: ["Launch Roar"],
    },
  },
  {
    id: "section-05",
    title: "Section 05",
    body: "Placeholder copy for the lift-off.",
    align: "right",
    start: 0.7,
    end: 0.9,
    animation: {
      sequenceLabels: ["Vertical Lift-Off / Touchdown", "Spiral Takeoff"],
    },
  },
  {
    id: "section-06",
    title: "Section 06",
    body: "Placeholder copy for the departure.",
    align: "left",
    start: 0.9,
    end: 1,
    animation: {
      loopLabel: "Forward March",
      oneShotLabels: ["Forward Wing Sweep", "Death Fall"],
    },
  },
];
