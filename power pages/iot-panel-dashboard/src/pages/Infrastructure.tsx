import { useState } from 'react';
import { InfrastructureDiagram } from '../components/InfrastructureDiagram';
import { NodeDetailPanel } from '../components/NodeDetailPanel';
import type { NodeDef } from '../data/nodeData';

const LEGEND = [
  { color: '#22C55E', label: 'Edge' },
  { color: '#F59E0B', label: 'Cloud' },
  { color: '#3B82F6', label: 'Platform' },
];

export default function Infrastructure() {
  const [selectedNode, setSelectedNode] = useState<NodeDef | null>(null);

  return (
    <div className="animate-in">
      {/* Page header */}
      <div style={{ marginBottom: 'var(--sp-6)' }}>
        <h1 style={{ fontSize: '13px', marginBottom: 'var(--sp-2)' }}>System Map</h1>
        <p style={{ fontSize: '12px', color: 'var(--color-text-muted)', maxWidth: '560px', lineHeight: 1.6 }}>
          Interactive infrastructure diagram of the Raspberry Pi IoT system.
          Hover to highlight connections — click any component to explore its role and interfaces.
        </p>
      </div>

      {/* Diagram card */}
      <div
        className="panel"
        style={{ padding: 'var(--sp-5)', overflow: 'hidden' }}
      >
        <InfrastructureDiagram
          onNodeClick={setSelectedNode}
          selectedId={selectedNode?.id}
        />
      </div>

      {/* Legend + hint row */}
      <div style={{
        display: 'flex',
        alignItems: 'center',
        gap: 'var(--sp-4)',
        marginTop: 'var(--sp-4)',
        flexWrap: 'wrap',
      }}>
        {LEGEND.map(({ color, label }) => (
          <div
            key={label}
            style={{ display: 'flex', alignItems: 'center', gap: 'var(--sp-2)' }}
          >
            <div style={{
              width: '8px',
              height: '8px',
              borderRadius: '50%',
              background: color,
              boxShadow: `0 0 6px ${color}80`,
              flexShrink: 0,
            }} />
            <span style={{
              fontSize: '10px',
              color: 'var(--color-text-muted)',
              fontFamily: 'var(--font-heading)',
              letterSpacing: '0.12em',
              textTransform: 'uppercase',
            }}>
              {label}
            </span>
          </div>
        ))}
        <span style={{
          marginLeft: 'auto',
          fontSize: '10px',
          color: 'var(--color-text-muted)',
          fontFamily: 'var(--font-heading)',
          letterSpacing: '0.1em',
          textTransform: 'uppercase',
        }}>
          Hover or click to explore
        </span>
      </div>

      {/* Detail panel (overlay) */}
      <NodeDetailPanel
        node={selectedNode}
        onClose={() => setSelectedNode(null)}
      />
    </div>
  );
}
