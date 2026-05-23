import React, { useState, useRef, useEffect, useMemo } from 'react';
import { NODE_DATA, CONNECTIONS, type NodeDef } from '../data/nodeData';

import iothubIcon    from '../assets/icons/iothub.svg';
import functionsIcon from '../assets/icons/functions.svg';
import signalrIcon   from '../assets/icons/signalr.svg';
import piIcon        from '../assets/icons/pi.svg';
import copilotIcon   from '../assets/icons/copilot.svg';
import dataverseIcon from '../assets/icons/dataverse.svg';
import flowsIcon     from '../assets/icons/flows.svg';
import pagesIcon     from '../assets/icons/pages.svg';
import edgeTierIcon    from '../assets/icons/edge-tier.svg';
import azureTierIcon   from '../assets/icons/azure-tier.svg';
import platformTierIcon from '../assets/icons/platform-tier.svg';

const NODE_ICONS: Record<string, string> = {
  iothub:    iothubIcon,
  functions: functionsIcon,
  signalr:   signalrIcon,
  pi:        piIcon,
  copilot:   copilotIcon,
  dataverse: dataverseIcon,
  flows:     flowsIcon,
  pages:     pagesIcon,
};

const NODE_W  = 150;
const NODE_H  = 56;
const HW      = NODE_W / 2;
const HH      = NODE_H / 2;
/** Left margin reserved for the tier logo badge */
const LOGO_GAP = 52;
/** Right padding */
const H_PAD    = 20;
/** Fixed SVG height — tiers are vertically fixed */
const SVG_H    = 560;

const TIER_BANDS = [
  { label: 'EDGE',           y: 55,  h: 145, fill: 'rgba(34, 197, 94, 0.13)',  logo: edgeTierIcon,     logoSize: 26 },
  { label: 'CLOUD',          y: 215, h: 115, fill: 'rgba(245, 158, 11, 0.11)', logo: azureTierIcon,    logoSize: 26 },
  { label: 'POWER PLATFORM', y: 395, h: 115, fill: 'rgba(59, 130, 246, 0.11)', logo: platformTierIcon, logoSize: 26 },
];

/**
 * Compute node cx positions dynamically based on available SVG width.
 *
 * Nodes in the same tier that share the same cx in nodeData are treated as the
 * same "column" (e.g. Switch and LED are stacked). Columns are spread evenly
 * across the usable width (after the logo margin).
 */
function computeLayout(svgWidth: number): Record<string, { cx: number; cy: number }> {
  const usableW = svgWidth - LOGO_GAP - H_PAD;
  const positions: Record<string, { cx: number; cy: number }> = {};

  // Group by tier
  const byTier: Record<string, NodeDef[]> = {};
  for (const n of NODE_DATA) {
    (byTier[n.tier] ??= []).push(n);
  }

  for (const nodes of Object.values(byTier)) {
    // Unique cx values → column slots, sorted left-to-right
    const cols = [...new Set(nodes.map(n => n.cx))].sort((a, b) => a - b);
    const numCols = cols.length;

    for (const node of nodes) {
      const colIdx = cols.indexOf(node.cx);
      const cx = LOGO_GAP + usableW * (colIdx + 0.5) / numCols;
      positions[node.id] = { cx, cy: node.cy };
    }
  }

  return positions;
}

interface Props {
  onNodeClick: (node: NodeDef) => void;
  selectedId?: string;
}

export const InfrastructureDiagram: React.FC<Props> = ({ onNodeClick, selectedId }) => {
  const [hoveredId, setHoveredId] = useState<string | null>(null);
  const [svgWidth, setSvgWidth] = useState(1100);
  const wrapperRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const el = wrapperRef.current;
    if (!el) return;
    // Set initial width synchronously so first paint is correct
    if (el.clientWidth > 100) setSvgWidth(el.clientWidth);
    const obs = new ResizeObserver(entries => {
      const w = Math.round(entries[0].contentRect.width);
      if (w > 100) setSvgWidth(w);
    });
    obs.observe(el);
    return () => obs.disconnect();
  }, []);

  const layout = useMemo(() => computeLayout(svgWidth), [svgWidth]);

  const nodeMap = Object.fromEntries(NODE_DATA.map(n => [n.id, n]));

  function getPath(fromId: string, toId: string): string {
    const from = layout[fromId];
    const to   = layout[toId];
    if (!from || !to) return '';

    const dy = to.cy - from.cy;
    const dx = to.cx - from.cx;

    if (Math.abs(dy) < 5) {
      return dx > 0
        ? `M ${from.cx + HW},${from.cy} L ${to.cx - HW},${to.cy}`
        : `M ${from.cx - HW},${from.cy} L ${to.cx + HW},${to.cy}`;
    }

    const midY = (from.cy + to.cy) / 2;
    return `M ${from.cx},${from.cy + HH} C ${from.cx},${midY} ${to.cx},${midY} ${to.cx},${to.cy - HH}`;
  }

  return (
    <div ref={wrapperRef} style={{ width: '100%' }}>
      <svg
        viewBox={`0 0 ${svgWidth} ${SVG_H}`}
        style={{ display: 'block', width: '100%', height: 'auto', userSelect: 'none' }}
        aria-label="IoT system infrastructure diagram — click any component for details"
        role="img"
      >
        {/* Tier background bands */}
        {TIER_BANDS.map(band => (
          <g key={band.label}>
            <rect x={0} y={band.y} width={svgWidth} height={band.h} style={{ fill: band.fill }} rx={3} />

            {/* Tier logo — top-left corner, within the logo gap margin */}
            <image
              href={band.logo}
              x={7}
              y={band.y + 7}
              width={band.logoSize}
              height={band.logoSize}
              style={{ opacity: 0.80 }}
            />

            {/* Right-side divider tick */}
            <line
              x1={svgWidth - 12} y1={band.y + 8}
              x2={svgWidth - 12} y2={band.y + band.h - 8}
              style={{ stroke: 'rgba(82, 96, 82, 0.2)', strokeWidth: 1 }}
            />
          </g>
        ))}

        {/* Connection paths */}
        {CONNECTIONS.map(conn => {
          const from = nodeMap[conn.from];
          const to   = nodeMap[conn.to];
          if (!from || !to) return null;

          const fromPos = layout[conn.from];
          const toPos   = layout[conn.to];
          if (!fromPos || !toPos) return null;

          const d = getPath(conn.from, conn.to);
          const isHighlighted =
            hoveredId  === conn.from || hoveredId  === conn.to ||
            selectedId === conn.from || selectedId === conn.to;

          return (
            <g key={`${conn.from}-${conn.to}`}>
              {/* Static base line */}
              <path
                d={d}
                fill="none"
                style={{
                  stroke: isHighlighted ? from.accentColor : 'rgba(80, 140, 80, 0.75)',
                  strokeWidth: isHighlighted ? 1.5 : 1,
                  opacity: isHighlighted ? 0.90 : 0.85,
                  strokeDasharray: isHighlighted ? 'none' : '4 3',
                  transition: 'stroke 0.2s, opacity 0.2s',
                }}
              />
              {/* Animated flow dots (visible only when highlighted) */}
              {isHighlighted && (
                <path
                  d={d}
                  fill="none"
                  style={{
                    stroke: from.accentColor,
                    strokeWidth: 1.5,
                    strokeDasharray: '6 12',
                    animation: 'flowLine 0.9s linear infinite',
                    opacity: 0.9,
                  }}
                />
              )}
              {/* Protocol label at mid-point — only when highlighted */}
              {isHighlighted && (() => {
                const mx = (fromPos.cx + toPos.cx) / 2;
                const my = (fromPos.cy + toPos.cy) / 2;
                return (
                  <text
                    key="label"
                    x={mx}
                    y={my - 6}
                    textAnchor="middle"
                    fontSize={8}
                    style={{
                      fill: from.accentColor,
                      fontFamily: "'IBM Plex Mono', monospace",
                      opacity: 0.85,
                    }}
                    letterSpacing={0.5}
                  >
                    {conn.label}
                  </text>
                );
              })()}
            </g>
          );
        })}

        {/* Nodes */}
        {NODE_DATA.map(node => {
          const pos = layout[node.id];
          if (!pos) return null;
          const { cx, cy } = pos;

          const isSelected = selectedId === node.id;
          const isHovered  = hoveredId  === node.id;
          const active     = isSelected || isHovered;

          return (
            <g
              key={node.id}
              onClick={() => onNodeClick(node)}
              onMouseEnter={() => setHoveredId(node.id)}
              onMouseLeave={() => setHoveredId(null)}
              onFocus={() => setHoveredId(node.id)}
              onBlur={() => setHoveredId(null)}
              tabIndex={0}
              role="button"
              aria-label={`${node.label} — ${node.sublabel}. Click for details.`}
              aria-pressed={isSelected}
              onKeyDown={e => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); onNodeClick(node); } }}
              style={{ cursor: 'pointer', outline: 'none' }}
            >
              {/* Glow halo */}
              {active && (
                <rect
                  x={cx - HW - 6} y={cy - HH - 6}
                  width={NODE_W + 12} height={NODE_H + 12}
                  rx={5}
                  style={{ fill: node.accentColor, opacity: 0.08 }}
                />
              )}

              {/* Node rectangle */}
              <rect
                x={cx - HW} y={cy - HH}
                width={NODE_W} height={NODE_H}
                rx={3}
                style={{
                  fill: active ? '#1E2A1E' : '#141E14',
                  stroke: active ? node.accentColor : 'rgba(90, 145, 90, 0.80)',
                  strokeWidth: active ? 1.5 : 1,
                  transition: 'fill 0.15s, stroke 0.15s',
                }}
              />

              {/* Corner accent mark (top-left) */}
              <polyline
                points={`${cx - HW + 8},${cy - HH} ${cx - HW},${cy - HH} ${cx - HW},${cy - HH + 8}`}
                fill="none"
                style={{
                  stroke: active ? node.accentColor : 'rgba(120, 170, 120, 0.75)',
                  strokeWidth: 1.2,
                  opacity: active ? 1.0 : 0.75,
                  transition: 'stroke 0.15s, opacity 0.15s',
                }}
              />

              {/* Icon — product logo or inline SVG for hardware nodes */}
              {NODE_ICONS[node.id] ? (
                <image
                  href={NODE_ICONS[node.id]}
                  x={cx - 13} y={cy - 25}
                  width={26} height={26}
                  style={{ opacity: active ? 1.0 : 0.82 }}
                />
              ) : node.id === 'switch' ? (
                <g>
                  <rect
                    x={cx - 18} y={cy - 23}
                    width={36} height={16} rx={8}
                    fill={`${node.accentColor}20`}
                    stroke={active ? node.accentColor : 'rgba(90,145,90,0.75)'}
                    strokeWidth={1.5}
                  />
                  <circle
                    cx={cx - 8} cy={cy - 15} r={5.5}
                    fill={active ? node.accentColor : 'rgba(90,145,90,0.75)'}
                  />
                </g>
              ) : node.id === 'led' ? (
                <g>
                  <circle
                    cx={cx} cy={cy - 15} r={10}
                    fill={`${node.accentColor}18`}
                    stroke={active ? node.accentColor : 'rgba(90,145,90,0.75)'}
                    strokeWidth={1.5}
                  />
                  <circle
                    cx={cx} cy={cy - 15} r={5}
                    fill={active ? node.accentColor : 'rgba(90,145,90,0.75)'}
                  />
                </g>
              ) : null}

              {/* Node sublabel */}
              <text
                x={cx} y={cy + 17}
                textAnchor="middle"
                fontSize={8.5}
                letterSpacing={0.3}
                style={{
                  fill: active ? 'rgba(220,235,220,0.85)' : '#AACAAA',
                  fontFamily: "'IBM Plex Mono', monospace",
                  transition: 'fill 0.15s',
                }}
              >
                {node.sublabel}
              </text>

              {/* Active indicator dot (top-right corner) */}
              {active && (
                <circle
                  cx={cx + HW - 9} cy={cy - HH + 9} r={3}
                  style={{
                    fill: node.accentColor,
                    animation: 'svgPulse 1.6s ease-in-out infinite',
                  }}
                />
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
};


