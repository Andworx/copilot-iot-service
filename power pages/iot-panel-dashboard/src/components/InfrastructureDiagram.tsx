import React, { useState } from 'react';
import { NODE_DATA, CONNECTIONS, type NodeDef } from '../data/nodeData';

const NODE_W = 150;
const NODE_H = 56;
const HW = NODE_W / 2;
const HH = NODE_H / 2;

const TIER_BANDS = [
  { label: 'EDGE',     y: 68,  h: 100, fill: 'rgba(34, 197, 94, 0.04)'  },
  { label: 'CLOUD',    y: 225, h: 110, fill: 'rgba(245, 158, 11, 0.04)' },
  { label: 'PLATFORM', y: 398, h: 110, fill: 'rgba(59, 130, 246, 0.04)' },
];

function getPath(from: NodeDef, to: NodeDef): string {
  const dy = to.cy - from.cy;
  const dx = to.cx - from.cx;

  if (Math.abs(dy) < 5) {
    // Horizontal connection
    return dx > 0
      ? `M ${from.cx + HW},${from.cy} L ${to.cx - HW},${to.cy}`
      : `M ${from.cx - HW},${from.cy} L ${to.cx + HW},${to.cy}`;
  }

  // Vertical / diagonal — bezier from bottom of source to top of dest
  const midY = (from.cy + to.cy) / 2;
  return `M ${from.cx},${from.cy + HH} C ${from.cx},${midY} ${to.cx},${midY} ${to.cx},${to.cy - HH}`;
}

interface Props {
  onNodeClick: (node: NodeDef) => void;
  selectedId?: string;
}

export const InfrastructureDiagram: React.FC<Props> = ({ onNodeClick, selectedId }) => {
  const [hoveredId, setHoveredId] = useState<string | null>(null);

  const nodeMap = Object.fromEntries(NODE_DATA.map(n => [n.id, n]));

  return (
    <svg
      viewBox="0 0 900 560"
      style={{ display: 'block', width: '100%', height: 'auto', userSelect: 'none' }}
      aria-label="IoT system infrastructure diagram — click any component for details"
      role="img"
    >
      {/* Tier background bands */}
      {TIER_BANDS.map(band => (
        <g key={band.label}>
          <rect x={0} y={band.y} width={900} height={band.h} style={{ fill: band.fill }} rx={3} />
          <text
            x={12}
            y={band.y + band.h / 2 + 4}
            fontSize={9}
            style={{ fill: 'rgba(82, 96, 82, 0.65)', fontFamily: "'IBM Plex Mono', monospace" }}
            letterSpacing={2}
          >
            {band.label}
          </text>
          {/* Right-side tier divider tick */}
          <line
            x1={888} y1={band.y + 8}
            x2={888} y2={band.y + band.h - 8}
            style={{ stroke: 'rgba(82, 96, 82, 0.2)', strokeWidth: 1 }}
          />
        </g>
      ))}

      {/* Connection paths */}
      {CONNECTIONS.map(conn => {
        const from = nodeMap[conn.from];
        const to   = nodeMap[conn.to];
        if (!from || !to) return null;

        const d = getPath(from, to);
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
                stroke: isHighlighted ? from.accentColor : '#243224',
                strokeWidth: isHighlighted ? 1.5 : 1,
                opacity: isHighlighted ? 0.75 : 0.55,
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
              const fromNode = from;
              const toNode   = to;
              const mx = (fromNode.cx + toNode.cx) / 2;
              const my = (fromNode.cy + toNode.cy) / 2;
              return (
                <text
                  key="label"
                  x={mx}
                  y={my - 6}
                  textAnchor="middle"
                  fontSize={8}
                  style={{
                    fill: fromNode.accentColor,
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
            {/* Glow halo behind node when active */}
            {active && (
              <rect
                x={node.cx - HW - 6}
                y={node.cy - HH - 6}
                width={NODE_W + 12}
                height={NODE_H + 12}
                rx={5}
                style={{ fill: node.accentColor, opacity: 0.08 }}
              />
            )}

            {/* Node rectangle */}
            <rect
              x={node.cx - HW}
              y={node.cy - HH}
              width={NODE_W}
              height={NODE_H}
              rx={3}
              style={{
                fill: active ? '#161E16' : '#0F160F',
                stroke: active ? node.accentColor : '#243224',
                strokeWidth: active ? 1.5 : 1,
                transition: 'fill 0.15s, stroke 0.15s',
              }}
            />

            {/* Corner accent mark (top-left) */}
            <polyline
              points={`${node.cx - HW + 8},${node.cy - HH} ${node.cx - HW},${node.cy - HH} ${node.cx - HW},${node.cy - HH + 8}`}
              fill="none"
              style={{
                stroke: active ? node.accentColor : '#526052',
                strokeWidth: 1.2,
                opacity: active ? 0.9 : 0.4,
                transition: 'stroke 0.15s, opacity 0.15s',
              }}
            />

            {/* Node label */}
            <text
              x={node.cx}
              y={node.cy - 7}
              textAnchor="middle"
              fontSize={11}
              fontWeight={600}
              letterSpacing={0.5}
              style={{
                fill: active ? node.accentColor : '#E8F0E8',
                fontFamily: "'IBM Plex Mono', monospace",
                transition: 'fill 0.15s',
              }}
            >
              {node.label}
            </text>

            {/* Node sublabel */}
            <text
              x={node.cx}
              y={node.cy + 12}
              textAnchor="middle"
              fontSize={8.5}
              letterSpacing={0.3}
              style={{
                fill: active ? 'rgba(200,212,200,0.6)' : '#526052',
                fontFamily: "'IBM Plex Mono', monospace",
                transition: 'fill 0.15s',
              }}
            >
              {node.sublabel}
            </text>

            {/* Active indicator dot (top-right corner) */}
            {active && (
              <circle
                cx={node.cx + HW - 9}
                cy={node.cy - HH + 9}
                r={3}
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
  );
};
