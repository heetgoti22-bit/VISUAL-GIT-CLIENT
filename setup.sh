#!/bin/bash
set -e
echo "🚀 Updating VisualGit with Pro Commit Graph..."

mkdir -p client/src server

# ─── Root package.json ───
cat > package.json << 'EOF'
{
  "name": "visual-git-client",
  "version": "1.0.0",
  "description": "A browser-based visual Git client with interactive commit graphs, diff viewer, and branch visualization",
  "private": true,
  "scripts": {
    "install:client": "cd client && npm install",
    "install:server": "cd server && npm install",
    "postinstall": "npm run install:client && npm run install:server",
    "build": "cd client && npm run build",
    "start": "cd server && node server.js",
    "dev": "concurrently \"cd server && npm run dev\" \"cd client && npm run dev\""
  },
  "keywords": ["git", "github", "visualization", "react", "d3", "commit-graph"],
  "author": "",
  "license": "MIT"
}
EOF

# ─── .gitignore ───
cat > .gitignore << 'EOF'
node_modules/
client/node_modules/
server/node_modules/
client/dist/
.env
.env.local
.env.production
.vscode/
.idea/
*.swp
*.swo
.DS_Store
Thumbs.db
*.log
npm-debug.log*
EOF

# ─── Procfile ───
cat > Procfile << 'EOF'
web: npm start
EOF

# ─── .env.example ───
cat > .env.example << 'EOF'
GITHUB_TOKEN=
PORT=3001
EOF

# ─── server/package.json ───
cat > server/package.json << 'EOF'
{
  "name": "visual-git-server",
  "version": "1.0.0",
  "description": "Backend API for Visual Git Client",
  "main": "server.js",
  "scripts": {
    "start": "node server.js",
    "dev": "node --watch server.js"
  },
  "author": "",
  "license": "MIT",
  "type": "commonjs",
  "dependencies": {
    "axios": "^1.13.6",
    "cors": "^2.8.6",
    "dotenv": "^17.3.1",
    "express": "^5.2.1"
  }
}
EOF

# ─── server/server.js ───
cat > server/server.js << 'SERVEREOF'
const express = require('express');
const cors = require('cors');
const axios = require('axios');
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3001;

app.use(cors());
app.use(express.json());

const ghApi = (endpoint, token) => {
  const headers = { Accept: 'application/vnd.github.v3+json' };
  if (token) headers.Authorization = `token ${token}`;
  else if (process.env.GITHUB_TOKEN) headers.Authorization = `token ${process.env.GITHUB_TOKEN}`;
  return axios.get(`https://api.github.com${endpoint}`, { headers });
};

app.get('/api/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

app.get('/api/repo/:owner/:repo', async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const token = req.headers['x-github-token'];
    const { data } = await ghApi(`/repos/${owner}/${repo}`, token);
    res.json({
      name: data.name, full_name: data.full_name, description: data.description,
      stars: data.stargazers_count, forks: data.forks_count, watchers: data.watchers_count,
      language: data.language, default_branch: data.default_branch,
      open_issues: data.open_issues_count, created_at: data.created_at, updated_at: data.updated_at,
      owner: { login: data.owner.login, avatar_url: data.owner.avatar_url },
    });
  } catch (err) {
    const status = err.response?.status || 500;
    const msg = status === 404 ? 'Repository not found' : status === 403 ? 'API rate limit exceeded. Add a GitHub token.' : err.message;
    res.status(status).json({ error: msg });
  }
});

app.get('/api/repo/:owner/:repo/branches', async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const token = req.headers['x-github-token'];
    const perPage = Math.min(parseInt(req.query.per_page) || 30, 100);
    const { data } = await ghApi(`/repos/${owner}/${repo}/branches?per_page=${perPage}`, token);
    res.json(data.map(b => ({ name: b.name, sha: b.commit.sha, protected: b.protected })));
  } catch (err) {
    res.status(err.response?.status || 500).json({ error: err.message });
  }
});

app.get('/api/repo/:owner/:repo/commits', async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const token = req.headers['x-github-token'];
    const sha = req.query.sha || 'main';
    const perPage = Math.min(parseInt(req.query.per_page) || 50, 100);
    const page = parseInt(req.query.page) || 1;
    const { data } = await ghApi(
      `/repos/${owner}/${repo}/commits?sha=${encodeURIComponent(sha)}&per_page=${perPage}&page=${page}`, token
    );
    res.json(data.map(c => ({
      sha: c.sha, message: c.commit.message,
      author: {
        name: c.commit.author?.name || 'Unknown', email: c.commit.author?.email || '',
        date: c.commit.author?.date, login: c.author?.login || '', avatar_url: c.author?.avatar_url || '',
      },
      committer: { name: c.commit.committer?.name || 'Unknown', date: c.commit.committer?.date },
      parents: c.parents?.map(p => ({ sha: p.sha })) || [],
    })));
  } catch (err) {
    res.status(err.response?.status || 500).json({ error: err.message });
  }
});

app.get('/api/repo/:owner/:repo/commits/:sha', async (req, res) => {
  try {
    const { owner, repo, sha } = req.params;
    const token = req.headers['x-github-token'];
    const { data } = await ghApi(`/repos/${owner}/${repo}/commits/${sha}`, token);
    res.json({
      sha: data.sha, message: data.commit.message,
      author: {
        name: data.commit.author?.name, email: data.commit.author?.email,
        date: data.commit.author?.date, login: data.author?.login, avatar_url: data.author?.avatar_url,
      },
      parents: data.parents?.map(p => ({ sha: p.sha })) || [],
      stats: data.stats,
      files: (data.files || []).map(f => ({
        filename: f.filename, status: f.status, additions: f.additions,
        deletions: f.deletions, changes: f.changes, patch: f.patch || '', blob_url: f.blob_url,
      })),
    });
  } catch (err) {
    res.status(err.response?.status || 500).json({ error: err.message });
  }
});

app.get('/api/repo/:owner/:repo/tree/:sha', async (req, res) => {
  try {
    const { owner, repo, sha } = req.params;
    const token = req.headers['x-github-token'];
    const { data } = await ghApi(`/repos/${owner}/${repo}/git/trees/${sha}?recursive=1`, token);
    res.json({ sha: data.sha, tree: data.tree.map(t => ({ path: t.path, type: t.type, sha: t.sha, size: t.size || 0 })), truncated: data.truncated });
  } catch (err) {
    res.status(err.response?.status || 500).json({ error: err.message });
  }
});

app.get('/api/repo/:owner/:repo/contents/{*filePath}', async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const filePath = req.params.filePath;
    const ref = req.query.ref || 'main';
    const token = req.headers['x-github-token'];
    const { data } = await ghApi(`/repos/${owner}/${repo}/contents/${filePath}?ref=${encodeURIComponent(ref)}`, token);
    res.json({ name: data.name, path: data.path, sha: data.sha, size: data.size, content: data.content ? Buffer.from(data.content, 'base64').toString('utf8') : null, encoding: data.encoding });
  } catch (err) {
    res.status(err.response?.status || 500).json({ error: err.message });
  }
});

app.get('/api/repo/:owner/:repo/contributors', async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const token = req.headers['x-github-token'];
    const { data } = await ghApi(`/repos/${owner}/${repo}/contributors?per_page=30`, token);
    res.json(data.map(c => ({ login: c.login, avatar_url: c.avatar_url, contributions: c.contributions })));
  } catch (err) {
    res.status(err.response?.status || 500).json({ error: err.message });
  }
});

app.get('/api/repo/:owner/:repo/compare/:base/:head', async (req, res) => {
  try {
    const { owner, repo, base, head } = req.params;
    const token = req.headers['x-github-token'];
    const { data } = await ghApi(`/repos/${owner}/${repo}/compare/${base}...${head}`, token);
    res.json({
      status: data.status, ahead_by: data.ahead_by, behind_by: data.behind_by, total_commits: data.total_commits,
      commits: data.commits.map(c => ({ sha: c.sha, message: c.commit.message.split('\n')[0], author: c.commit.author?.name, date: c.commit.author?.date })),
      files: (data.files || []).map(f => ({ filename: f.filename, status: f.status, additions: f.additions, deletions: f.deletions, patch: f.patch || '' })),
    });
  } catch (err) {
    res.status(err.response?.status || 500).json({ error: err.message });
  }
});

app.get('/api/rate-limit', async (req, res) => {
  try {
    const token = req.headers['x-github-token'];
    const { data } = await ghApi('/rate_limit', token);
    res.json({ limit: data.rate.limit, remaining: data.rate.remaining, reset: new Date(data.rate.reset * 1000).toISOString() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.use(express.static(path.join(__dirname, '..', 'client', 'dist')));
app.get('/{*splat}', (req, res) => {
  res.sendFile(path.join(__dirname, '..', 'client', 'dist', 'index.html'));
});

app.listen(PORT, () => { console.log(`Visual Git Server running on port ${PORT}`); });
SERVEREOF

# ─── client/package.json ───
cat > client/package.json << 'EOF'
{
  "name": "visual-git-client",
  "private": true,
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "d3": "^7.9.0",
    "react": "^19.2.4",
    "react-dom": "^19.2.4"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^6.0.0",
    "vite": "^8.0.0"
  }
}
EOF

# ─── client/vite.config.js ───
cat > client/vite.config.js << 'EOF'
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
      },
    },
  },
});
EOF

# ─── client/index.html ───
cat > client/index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>VisualGit — Interactive Git Repository Explorer</title>
    <meta name="description" content="A browser-based visual Git client. Explore commit graphs, branches, and diffs for any public GitHub repository." />
    <link rel="icon" href="data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 viewBox=%220 0 100 100%22><text y=%22.9em%22 font-size=%2290%22>⬡</text></svg>" />
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF

# ─── client/src/main.jsx ───
cat > client/src/main.jsx << 'MAINEOF'
import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App.jsx';

const style = document.createElement('style');
style.textContent = `
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { background: #0a0e17; color: #e2e8f0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; overflow: hidden; }
  ::-webkit-scrollbar { width: 6px; height: 6px; }
  ::-webkit-scrollbar-track { background: #111827; }
  ::-webkit-scrollbar-thumb { background: #2a3a4d; border-radius: 3px; }
  ::-webkit-scrollbar-thumb:hover { background: #3b82f6; }
  ::selection { background: #3b82f644; }
  input::placeholder { color: #475569; }
`;
document.head.appendChild(style);

createRoot(document.getElementById('root')).render(
  <StrictMode><App /></StrictMode>
);
MAINEOF

# ─── client/src/App.jsx (FULL REWRITE with Pro Graph) ───
cat > client/src/App.jsx << 'APPEOF'
import { useState, useEffect, useRef, useCallback } from 'react';
import * as d3 from 'd3';

const API = import.meta.env.VITE_API_BASE || '';
const T = {
  bg:'#0a0e17',surface:'#111827',surfaceAlt:'#1a2233',
  border:'#1e2d3d',text:'#e2e8f0',textMuted:'#64748b',textDim:'#475569',
  accent:'#3b82f6',green:'#22c55e',red:'#ef4444',orange:'#f59e0b',
  purple:'#a78bfa',pink:'#ec4899',cyan:'#06b6d4',teal:'#14b8a6',
  branches:['#3b82f6','#22c55e','#a78bfa','#ec4899','#f59e0b','#06b6d4','#ef4444','#14b8a6'],
};

const shortSha = s => s?.slice(0,7)||'';
const timeAgo = d => {
  if(!d) return '';
  const s=Math.floor((Date.now()-new Date(d))/1000);
  if(s<60) return 'just now';
  if(s<3600) return `${Math.floor(s/60)}m ago`;
  if(s<86400) return `${Math.floor(s/3600)}h ago`;
  if(s<2592000) return `${Math.floor(s/86400)}d ago`;
  return new Date(d).toLocaleDateString('en-US',{month:'short',day:'numeric',year:'numeric'});
};
const apiFetch = async(p,tk)=>{
  const h={}; if(tk) h['x-github-token']=tk;
  const r=await fetch(`${API}${p}`,{headers:h});
  if(!r.ok){const e=await r.json().catch(()=>({})); throw new Error(e.error||`HTTP ${r.status}`);}
  return r.json();
};
const getSha = p => typeof p==='string'?p:p?.sha||'';

// ═══════════════════════════════════════════
// PRO COMMIT GRAPH — Vertical, zoomable, interactive
// ═══════════════════════════════════════════
function CommitGraph({ commits, branchColors, selectedSha, onSelect, branchFilter, hoveredSha, setHoveredSha }) {
  const svgRef = useRef(null);
  const wrapRef = useRef(null);
  const zoomRef = useRef(null);
  const [dims, setDims] = useState({ w: 900, h: 700 });
  const [zoomLevel, setZoomLevel] = useState(1);

  useEffect(() => {
    const el = wrapRef.current;
    if (!el) return;
    const ro = new ResizeObserver(e => {
      const { width, height } = e[0].contentRect;
      if (width > 0 && height > 0) setDims({ w: width, h: height });
    });
    ro.observe(el);
    return () => ro.disconnect();
  }, []);

  const zoomTo = useCallback((scale) => {
    if (!svgRef.current || !zoomRef.current) return;
    const svg = d3.select(svgRef.current);
    svg.transition().duration(300).call(zoomRef.current.scaleTo, scale);
  }, []);

  useEffect(() => {
    if (!commits.length || !svgRef.current) return;
    const svg = d3.select(svgRef.current);
    svg.selectAll('*').remove();

    const filtered = branchFilter === 'all' ? commits : commits.filter(c => c.branch === branchFilter);
    if (!filtered.length) return;

    // Layout config
    const ROW_H = 60;
    const COL_W = 90;
    const PAD_TOP = 40;
    const PAD_LEFT = 60;
    const totalH = Math.max(dims.h, filtered.length * ROW_H + PAD_TOP * 2);

    // Assign columns per branch
    const branchNames = [...new Set(filtered.map(c => c.branch))];
    const branchCol = {};
    branchNames.forEach((b, i) => { branchCol[b] = i; });

    // Compute positions (vertical layout: newest on top)
    const pos = new Map();
    filtered.forEach((c, i) => {
      const x = PAD_LEFT + branchCol[c.branch] * COL_W;
      const y = PAD_TOP + i * ROW_H;
      pos.set(c.sha, { x, y });
    });

    const defs = svg.append('defs');

    // Glow filter
    const glow = defs.append('filter').attr('id', 'glow').attr('x', '-50%').attr('y', '-50%').attr('width', '200%').attr('height', '200%');
    glow.append('feGaussianBlur').attr('stdDeviation', '4').attr('result', 'blur');
    glow.append('feMerge').selectAll('feMergeNode').data(['blur', 'SourceGraphic']).enter()
      .append('feMergeNode').attr('in', d => d);

    // Hover glow filter
    const hGlow = defs.append('filter').attr('id', 'hoverGlow').attr('x', '-50%').attr('y', '-50%').attr('width', '200%').attr('height', '200%');
    hGlow.append('feGaussianBlur').attr('stdDeviation', '6').attr('result', 'blur');
    hGlow.append('feMerge').selectAll('feMergeNode').data(['blur', 'SourceGraphic']).enter()
      .append('feMergeNode').attr('in', d => d);

    const root = svg.append('g');

    // Draw branch lane labels at top
    branchNames.forEach((b, i) => {
      const x = PAD_LEFT + i * COL_W;
      const col = branchColors[b] || T.accent;
      // Vertical lane line
      root.append('line')
        .attr('x1', x).attr('x2', x)
        .attr('y1', 0).attr('y2', totalH)
        .attr('stroke', col).attr('stroke-opacity', 0.06).attr('stroke-width', 1);
    });

    // Draw edges (parent links)
    filtered.forEach(c => {
      const p = pos.get(c.sha);
      if (!p) return;
      const col = branchColors[c.branch] || T.accent;
      (c.parents || []).forEach(par => {
        const pSha = getSha(par);
        const pp = pos.get(pSha);
        if (!pp) return;

        if (pp.x === p.x) {
          // Same branch — straight vertical line
          root.append('line')
            .attr('x1', p.x).attr('y1', p.y).attr('x2', pp.x).attr('y2', pp.y)
            .attr('stroke', col).attr('stroke-width', 2.5).attr('stroke-opacity', 0.5);
        } else {
          // Cross-branch — smooth bezier curve
          const midY = (p.y + pp.y) / 2;
          root.append('path')
            .attr('d', `M${p.x},${p.y} C${p.x},${midY} ${pp.x},${midY} ${pp.x},${pp.y}`)
            .attr('fill', 'none').attr('stroke', col)
            .attr('stroke-width', 2).attr('stroke-opacity', 0.35)
            .attr('stroke-dasharray', '6,3');
        }
      });
    });

    // Draw nodes
    filtered.forEach(c => {
      const p = pos.get(c.sha);
      if (!p) return;
      const col = branchColors[c.branch] || T.accent;
      const sel = c.sha === selectedSha;
      const isMerge = (c.parents || []).length > 1;
      const r = isMerge ? 8 : 6;
      const authorName = c.author?.name || c.author || 'Unknown';
      const date = c.date || c.author?.date;

      const node = root.append('g')
        .attr('transform', `translate(${p.x},${p.y})`)
        .style('cursor', 'pointer');

      // Selected glow ring
      if (sel) {
        node.append('circle').attr('r', r + 14)
          .attr('fill', col).attr('opacity', 0.08);
        node.append('circle').attr('r', r + 8)
          .attr('fill', 'none').attr('stroke', col).attr('stroke-width', 2)
          .attr('opacity', 0.3).attr('filter', 'url(#glow)');
      }

      // Hover ring (hidden by default, shown on hover)
      const hoverRing = node.append('circle')
        .attr('r', r + 10).attr('fill', col).attr('opacity', 0)
        .attr('class', 'hover-ring');

      // Main circle
      const outerCircle = node.append('circle').attr('r', r + 2)
        .attr('fill', sel ? col : T.bg)
        .attr('stroke', col).attr('stroke-width', sel ? 2.5 : 2);

      const innerCircle = node.append('circle').attr('r', r)
        .attr('fill', col).attr('opacity', sel ? 1 : 0.85);

      if (isMerge) {
        node.append('circle').attr('r', 3).attr('fill', T.bg);
      }

      // Commit message label
      const msgX = PAD_LEFT + branchNames.length * COL_W + 20;
      node.append('text')
        .attr('x', msgX - p.x)
        .attr('y', 4)
        .attr('fill', sel ? T.text : T.textMuted)
        .attr('font-size', 12.5)
        .attr('font-family', 'system-ui, sans-serif')
        .attr('font-weight', sel ? 600 : 400)
        .text(c.message?.split('\n')[0]?.substring(0, 70) + (c.message?.length > 70 ? '...' : ''));

      // SHA label near node
      node.append('text')
        .attr('x', -r - 8).attr('y', 4).attr('text-anchor', 'end')
        .attr('fill', sel ? col : T.textDim)
        .attr('font-size', 9.5)
        .attr('font-family', "'SF Mono','Fira Code',monospace")
        .attr('font-weight', sel ? 700 : 400)
        .attr('opacity', 0);

      // Tooltip group (shown on hover)
      const tooltip = node.append('g').attr('opacity', 0).attr('class', 'tooltip');
      const tooltipBg = tooltip.append('rect')
        .attr('x', r + 12).attr('y', -35).attr('rx', 8).attr('ry', 8)
        .attr('width', 260).attr('height', 52)
        .attr('fill', T.surface).attr('stroke', col + '44').attr('stroke-width', 1);
      tooltip.append('text').attr('x', r + 22).attr('y', -16)
        .attr('fill', col).attr('font-size', 11).attr('font-weight', 600)
        .attr('font-family', "'SF Mono',monospace")
        .text(shortSha(c.sha));
      tooltip.append('text').attr('x', r + 85).attr('y', -16)
        .attr('fill', T.textMuted).attr('font-size', 10).attr('font-family', 'system-ui')
        .text(`${authorName}`);
      tooltip.append('text').attr('x', r + 22).attr('y', 2)
        .attr('fill', T.textMuted).attr('font-size', 10).attr('font-family', 'system-ui')
        .text(date ? timeAgo(date) : '');

      // Hover interactions
      node.on('mouseenter', function() {
        hoverRing.transition().duration(200).attr('opacity', 0.12);
        outerCircle.transition().duration(200).attr('stroke-width', 3);
        innerCircle.transition().duration(200).attr('r', r + 1);
        tooltip.transition().duration(200).attr('opacity', 1);
        d3.select(this).raise();
        if (setHoveredSha) setHoveredSha(c.sha);
      });
      node.on('mouseleave', function() {
        hoverRing.transition().duration(200).attr('opacity', 0);
        outerCircle.transition().duration(200).attr('stroke-width', sel ? 2.5 : 2);
        innerCircle.transition().duration(200).attr('r', r);
        tooltip.transition().duration(200).attr('opacity', 0);
        if (setHoveredSha) setHoveredSha(null);
      });
      node.on('click', () => onSelect(c));
    });

    // Zoom & Pan with grab cursor
    const zoomBehavior = d3.zoom()
      .scaleExtent([0.15, 5])
      .on('zoom', (e) => {
        root.attr('transform', e.transform);
        setZoomLevel(e.transform.k);
      });

    svg.call(zoomBehavior)
      .on('mousedown.zoom', function() { d3.select(this).style('cursor', 'grabbing'); })
      .on('mouseup.zoom', function() { d3.select(this).style('cursor', 'grab'); })
      .style('cursor', 'grab');

    zoomRef.current = zoomBehavior;

    // Initial position
    svg.call(zoomBehavior.transform, d3.zoomIdentity.translate(20, 20).scale(0.9));

  }, [commits, dims, selectedSha, branchFilter, branchColors, setHoveredSha, onSelect]);

  return (
    <div ref={wrapRef} style={{ width: '100%', height: '100%', position: 'relative', overflow: 'hidden' }}>
      <svg ref={svgRef} width={dims.w} height={dims.h} style={{ background: T.bg, display: 'block' }} />

      {/* Zoom Controls */}
      <div style={{
        position: 'absolute', bottom: 16, right: 16,
        display: 'flex', flexDirection: 'column', gap: 4,
        background: T.surface, border: `1px solid ${T.border}`,
        borderRadius: 10, padding: 4, boxShadow: '0 4px 20px rgba(0,0,0,0.4)',
      }}>
        <button onClick={() => zoomTo(Math.min(zoomLevel * 1.3, 5))} style={{
          width: 36, height: 36, background: T.surfaceAlt, border: `1px solid ${T.border}`,
          borderRadius: 8, color: T.text, fontSize: 18, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>+</button>
        <div style={{
          textAlign: 'center', color: T.textMuted, fontSize: 10, padding: '2px 0',
        }}>{Math.round(zoomLevel * 100)}%</div>
        <button onClick={() => zoomTo(Math.max(zoomLevel / 1.3, 0.15))} style={{
          width: 36, height: 36, background: T.surfaceAlt, border: `1px solid ${T.border}`,
          borderRadius: 8, color: T.text, fontSize: 18, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
        }}>−</button>
        <div style={{ height: 1, background: T.border, margin: '2px 4px' }}/>
        <button onClick={() => {
          if (svgRef.current && zoomRef.current) {
            d3.select(svgRef.current).transition().duration(400)
              .call(zoomRef.current.transform, d3.zoomIdentity.translate(20, 20).scale(0.9));
          }
        }} style={{
          width: 36, height: 36, background: T.surfaceAlt, border: `1px solid ${T.border}`,
          borderRadius: 8, color: T.textMuted, fontSize: 11, cursor: 'pointer',
          display: 'flex', alignItems: 'center', justifyContent: 'center', fontWeight: 600,
        }}>Fit</button>
      </div>

      {/* Legend */}
      <div style={{
        position: 'absolute', bottom: 16, left: 16, color: T.textDim,
        fontSize: 11, background: T.surface + 'ee', padding: '6px 12px', borderRadius: 6,
        border: `1px solid ${T.border}`, display: 'flex', gap: 12,
      }}>
        <span>🖱 Scroll to zoom</span>
        <span>✋ Drag to pan</span>
        <span>👆 Click node for diff</span>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════
// COMMIT LIST VIEW
// ═══════════════════════════════════════════
function CommitList({ commits, selectedSha, onSelect, branchColors }) {
  return (
    <div style={{ overflowY: 'auto', height: '100%' }}>
      {commits.map((c, i) => {
        const col = branchColors[c.branch] || T.accent;
        const sel = c.sha === selectedSha;
        const authorName = c.author?.name || c.author || 'Unknown';
        const date = c.date || c.author?.date;
        return (
          <div key={c.sha} onClick={() => onSelect(c)} style={{
            padding: '12px 20px', cursor: 'pointer',
            borderBottom: `1px solid ${T.border}`,
            background: sel ? T.accent + '0d' : 'transparent',
            borderLeft: `3px solid ${col}`,
            display: 'flex', gap: 14, alignItems: 'flex-start',
          }}>
            <div style={{ paddingTop: 4 }}>
              <div style={{
                width: 10, height: 10, borderRadius: '50%',
                background: sel ? col : T.bg, border: `2px solid ${col}`,
              }}/>
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ color: T.text, fontSize: 13, fontWeight: 500, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                {c.message?.split('\n')[0]}
              </div>
              <div style={{ display: 'flex', gap: 8, marginTop: 5, alignItems: 'center', flexWrap: 'wrap' }}>
                <code style={{ color: col, fontSize: 11, background: col + '11', padding: '1px 6px', borderRadius: 3 }}>{shortSha(c.sha)}</code>
                <span style={{ color: T.green, fontSize: 12 }}>{authorName}</span>
                <span style={{ color: T.textDim, fontSize: 11 }}>{date ? timeAgo(date) : ''}</span>
                {(c.parents || []).length > 1 && (
                  <span style={{ color: T.purple, fontSize: 10, background: T.purple + '15', padding: '1px 6px', borderRadius: 3 }}>merge</span>
                )}
              </div>
            </div>
            <div style={{ background: col + '15', color: col, padding: '2px 8px', borderRadius: 4, fontSize: 10, whiteSpace: 'nowrap' }}>{c.branch}</div>
          </div>
        );
      })}
    </div>
  );
}

// ═══════════════════════════════════════════
// DIFF PANEL
// ═══════════════════════════════════════════
function DiffPanel({ commit, owner, repo, token, onClose }) {
  const [detail, setDetail] = useState(null);
  const [loading, setLoading] = useState(false);
  const [exp, setExp] = useState(new Set());

  useEffect(() => {
    if (!commit || !owner || !repo) return;
    setLoading(true); setExp(new Set());
    apiFetch(`/api/repo/${owner}/${repo}/commits/${commit.sha}`, token)
      .then(d => { setDetail(d); setLoading(false); })
      .catch(() => setLoading(false));
  }, [commit?.sha]);

  if (!commit) return null;
  const authorName = commit.author?.name || commit.author || 'Unknown';
  const date = commit.date || commit.author?.date;
  const toggle = fn => setExp(p => { const s = new Set(p); s.has(fn)?s.delete(fn):s.add(fn); return s; });

  return (
    <div style={{
      position: 'fixed', top: 0, right: 0, width: 560, height: '100vh',
      background: T.surface, borderLeft: `1px solid ${T.border}`,
      zIndex: 1000, display: 'flex', flexDirection: 'column',
      boxShadow: '-8px 0 30px rgba(0,0,0,0.6)',
    }}>
      <div style={{
        padding: '14px 20px', borderBottom: `1px solid ${T.border}`,
        display: 'flex', justifyContent: 'space-between', alignItems: 'center', background: T.surfaceAlt,
      }}>
        <span style={{ color: T.text, fontWeight: 600, fontSize: 14 }}>Commit Details</span>
        <button onClick={onClose} style={{ background: 'none', border: 'none', color: T.textMuted, cursor: 'pointer', fontSize: 18 }}>✕</button>
      </div>
      <div style={{ overflowY: 'auto', flex: 1, padding: 20 }}>
        <div style={{ background: T.bg, borderRadius: 10, padding: 18, border: `1px solid ${T.border}`, marginBottom: 20 }}>
          <code style={{ color: T.accent, fontSize: 12, background: T.accent + '15', padding: '2px 8px', borderRadius: 4 }}>{commit.sha}</code>
          {(commit.parents||[]).length > 1 && <span style={{ color: T.purple, fontSize: 10, background: T.purple + '15', padding: '2px 8px', borderRadius: 4, marginLeft: 8 }}>Merge</span>}
          <p style={{ color: T.text, margin: '12px 0 8px', fontSize: 14, fontWeight: 600, lineHeight: 1.5 }}>{commit.message?.split('\n')[0]}</p>
          <div style={{ color: T.textMuted, fontSize: 12 }}>
            <span style={{ color: T.green }}>{authorName}</span>
            <span style={{ margin: '0 8px' }}>·</span>
            <span>{date ? timeAgo(date) : ''}</span>
          </div>
          {(commit.parents||[]).length > 0 && (
            <div style={{ marginTop: 8, fontSize: 11, color: T.textDim }}>
              Parents: {commit.parents.map(p => shortSha(getSha(p))).join(' → ')}
            </div>
          )}
        </div>

        {loading ? (
          <div style={{ textAlign: 'center', padding: 30, color: T.textMuted }}>Loading diff...</div>
        ) : detail?.files ? (
          <>
            <div style={{ display: 'flex', gap: 16, marginBottom: 16, fontSize: 13, padding: '10px 14px', background: T.bg, borderRadius: 8, border: `1px solid ${T.border}`, color: T.textMuted }}>
              <span><strong style={{ color: T.text }}>{detail.files.length}</strong> files</span>
              <span style={{ color: T.green }}>+{detail.stats?.additions||0}</span>
              <span style={{ color: T.red }}>-{detail.stats?.deletions||0}</span>
            </div>
            {detail.files.map((f, i) => {
              const sc = f.status==='added'?T.green:f.status==='removed'?T.red:f.status==='renamed'?T.cyan:T.orange;
              const sl = f.status==='added'?'A':f.status==='removed'?'D':f.status==='renamed'?'R':'M';
              const open = exp.has(f.filename);
              return (
                <div key={i} style={{ background: T.bg, borderRadius: 8, marginBottom: 8, border: `1px solid ${T.border}`, overflow: 'hidden' }}>
                  <div onClick={() => toggle(f.filename)} style={{
                    padding: '10px 14px', display: 'flex', justifyContent: 'space-between', alignItems: 'center', cursor: 'pointer',
                    borderBottom: open ? `1px solid ${T.border}` : 'none',
                  }}>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8, flex: 1, minWidth: 0 }}>
                      <span style={{ color: sc, fontWeight: 700, fontSize: 11, background: sc+'18', padding: '1px 5px', borderRadius: 3, fontFamily: 'monospace' }}>{sl}</span>
                      <span style={{ color: T.text, fontSize: 12, fontFamily: 'monospace', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{f.filename}</span>
                    </div>
                    <div style={{ display: 'flex', gap: 8, flexShrink: 0, alignItems: 'center' }}>
                      <span style={{ color: T.green, fontSize: 11 }}>+{f.additions}</span>
                      <span style={{ color: T.red, fontSize: 11 }}>-{f.deletions}</span>
                      <span style={{ color: T.textDim, transform: open?'rotate(180deg)':'none', transition: 'transform .2s' }}>▾</span>
                    </div>
                  </div>
                  {open && f.patch && (
                    <pre style={{ margin: 0, padding: 12, fontSize: 11.5, lineHeight: 1.7, overflowX: 'auto', maxHeight: 400, color: T.textMuted, fontFamily: "'SF Mono','Fira Code',monospace" }}>
                      {f.patch.split('\n').map((line, li) => (
                        <div key={li} style={{
                          color: line.startsWith('+')&&!line.startsWith('+++')?T.green:line.startsWith('-')&&!line.startsWith('---')?T.red:line.startsWith('@@')?T.purple:T.textMuted,
                          background: line.startsWith('+')&&!line.startsWith('+++')?'rgba(34,197,94,0.07)':line.startsWith('-')&&!line.startsWith('---')?'rgba(239,68,68,0.07)':'transparent',
                          padding: '0 6px',
                          borderLeft: `2px solid ${line.startsWith('+')&&!line.startsWith('+++')?T.green+'44':line.startsWith('-')&&!line.startsWith('---')?T.red+'44':'transparent'}`,
                        }}>{line || ' '}</div>
                      ))}
                    </pre>
                  )}
                </div>
              );
            })}
          </>
        ) : null}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════
// MAIN APP
// ═══════════════════════════════════════════
export default function App() {
  const [url,setUrl]=useState('');
  const [token,setToken]=useState('');
  const [showToken,setShowToken]=useState(false);
  const [repoInfo,setRepoInfo]=useState(null);
  const [branches,setBranches]=useState([]);
  const [commits,setCommits]=useState([]);
  const [branchColors,setBranchColors]=useState({});
  const [contributors,setContributors]=useState([]);
  const [loading,setLoading]=useState(false);
  const [error,setError]=useState('');
  const [selectedCommit,setSelectedCommit]=useState(null);
  const [branchFilter,setBranchFilter]=useState('all');
  const [view,setView]=useState('graph');
  const [searchTerm,setSearchTerm]=useState('');
  const [hoveredSha,setHoveredSha]=useState(null);

  const parseRepo=u=>{
    const m=u.match(/github\.com\/([^/]+)\/([^/\s#?]+)/);
    if(m) return {owner:m[1],repo:m[2].replace(/\.git$/,'')};
    const parts=u.replace(/\.git$/,'').split('/').filter(Boolean);
    if(parts.length>=2) return {owner:parts[parts.length-2],repo:parts[parts.length-1]};
    return null;
  };
  const parsed=parseRepo(url);

  const fetchRepo=useCallback(async()=>{
    const p=parseRepo(url);
    if(!p){setError('Enter a valid GitHub URL');return;}
    setLoading(true);setError('');setCommits([]);setBranches([]);
    setRepoInfo(null);setSelectedCommit(null);setBranchFilter('all');setContributors([]);
    try{
      const info=await apiFetch(`/api/repo/${p.owner}/${p.repo}`,token);
      setRepoInfo(info);
      const br=await apiFetch(`/api/repo/${p.owner}/${p.repo}/branches`,token);
      setBranches(br);
      const colors={};
      br.forEach((b,i)=>{colors[b.name]=T.branches[i%T.branches.length];});
      setBranchColors(colors);
      const allCommits=new Map();
      await Promise.all(br.slice(0,10).map(async branch=>{
        try{
          const data=await apiFetch(`/api/repo/${p.owner}/${p.repo}/commits?sha=${encodeURIComponent(branch.name)}&per_page=40`,token);
          data.forEach(c=>{if(!allCommits.has(c.sha)) allCommits.set(c.sha,{...c,branch:branch.name,message:c.message?.split('\n')[0]||''});});
        }catch{}
      }));
      setCommits([...allCommits.values()].sort((a,b)=>new Date(b.author?.date||0)-new Date(a.author?.date||0)));
      try{setContributors(await apiFetch(`/api/repo/${p.owner}/${p.repo}/contributors`,token));}catch{}
    }catch(err){setError(err.message);}finally{setLoading(false);}
  },[url,token]);

  const filteredCommits=(branchFilter==='all'?commits:commits.filter(c=>c.branch===branchFilter))
    .filter(c=>{
      if(!searchTerm) return true;
      const s=searchTerm.toLowerCase();
      return (c.message||'').toLowerCase().includes(s)||(c.author?.name||'').toLowerCase().includes(s)||c.sha.startsWith(s);
    });

  return (
    <div style={{background:T.bg,color:T.text,height:'100vh',fontFamily:"-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif",display:'flex',flexDirection:'column'}}>
      {/* Header */}
      <header style={{padding:'12px 24px',borderBottom:`1px solid ${T.border}`,display:'flex',alignItems:'center',gap:16,background:T.surface,flexShrink:0}}>
        <div style={{display:'flex',alignItems:'center',gap:8,flexShrink:0}}>
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={T.accent} strokeWidth="2" strokeLinecap="round">
            <circle cx="12" cy="5" r="2"/><circle cx="12" cy="19" r="2"/><circle cx="19" cy="12" r="2"/>
            <line x1="12" y1="7" x2="12" y2="17"/><path d="M14 5h2a2 2 0 0 1 2 2v3"/>
          </svg>
          <span style={{fontWeight:800,fontSize:16}}>Visual<span style={{color:T.accent}}>Git</span></span>
        </div>
        <div style={{flex:1,display:'flex',gap:8,maxWidth:680}}>
          <div style={{flex:1,display:'flex',alignItems:'center',gap:8,background:T.bg,border:`1px solid ${T.border}`,borderRadius:8,padding:'0 12px'}}>
            <span style={{color:T.textDim}}>🔍</span>
            <input value={url} onChange={e=>setUrl(e.target.value)} onKeyDown={e=>e.key==='Enter'&&fetchRepo()}
              placeholder="github.com/owner/repo"
              style={{flex:1,background:'none',border:'none',color:T.text,fontSize:13,outline:'none',padding:'8px 0'}}/>
          </div>
          <button onClick={()=>setShowToken(!showToken)} style={{
            background:token?T.green+'18':T.bg,border:`1px solid ${token?T.green+'55':T.border}`,
            borderRadius:8,padding:'0 10px',cursor:'pointer',color:token?T.green:T.textMuted,fontSize:14,
          }}>🔑</button>
          <button onClick={fetchRepo} disabled={loading||!url} style={{
            background:T.accent,color:'#fff',border:'none',borderRadius:8,padding:'8px 22px',
            fontWeight:600,cursor:loading?'wait':'pointer',fontSize:13,opacity:loading||!url?0.5:1,
          }}>{loading?'...':'Explore'}</button>
        </div>
      </header>

      {showToken&&(
        <div style={{padding:'8px 24px',background:T.surfaceAlt,borderBottom:`1px solid ${T.border}`,display:'flex',gap:8,alignItems:'center',flexShrink:0}}>
          <span style={{color:T.textMuted,fontSize:12}}>Token:</span>
          <input value={token} onChange={e=>setToken(e.target.value)} placeholder="ghp_xxxx..." type="password"
            style={{flex:1,maxWidth:360,background:T.bg,border:`1px solid ${T.border}`,borderRadius:6,padding:'5px 10px',color:T.text,fontSize:12,outline:'none'}}/>
        </div>
      )}

      {error&&(
        <div style={{padding:'10px 24px',background:T.red+'12',borderBottom:`1px solid ${T.red}33`,color:T.red,fontSize:13,display:'flex',justifyContent:'space-between',flexShrink:0}}>
          <span>{error}</span>
          <button onClick={()=>setError('')} style={{background:'none',border:'none',color:T.red,cursor:'pointer'}}>✕</button>
        </div>
      )}

      {loading&&(
        <div style={{flex:1,display:'flex',justifyContent:'center',alignItems:'center'}}>
          <div style={{textAlign:'center'}}>
            <div style={{width:40,height:40,border:`3px solid ${T.border}`,borderTop:`3px solid ${T.accent}`,borderRadius:'50%',animation:'spin .8s linear infinite',margin:'0 auto'}}/>
            <div style={{color:T.textMuted,fontSize:13,marginTop:14}}>Exploring {parsed?.owner}/{parsed?.repo}...</div>
            <style>{`@keyframes spin{to{transform:rotate(360deg)}}`}</style>
          </div>
        </div>
      )}

      {!loading&&commits.length>0&&(
        <div style={{flex:1,display:'flex',flexDirection:'column',overflow:'hidden'}}>
          {/* Repo info */}
          {repoInfo&&(
            <div style={{padding:'10px 24px',background:T.surface,borderBottom:`1px solid ${T.border}`,display:'flex',justifyContent:'space-between',alignItems:'center',flexWrap:'wrap',gap:12,flexShrink:0}}>
              <div style={{display:'flex',alignItems:'center',gap:10}}>
                {repoInfo.owner?.avatar_url&&<img src={repoInfo.owner.avatar_url} alt="" style={{width:26,height:26,borderRadius:6}}/>}
                <div>
                  <span style={{fontWeight:700,fontSize:14}}><span style={{color:T.textMuted}}>{repoInfo.owner?.login}/</span>{repoInfo.name}</span>
                  {repoInfo.description&&<div style={{color:T.textDim,fontSize:11,marginTop:1,maxWidth:350,overflow:'hidden',textOverflow:'ellipsis',whiteSpace:'nowrap'}}>{repoInfo.description}</div>}
                </div>
              </div>
              <div style={{display:'flex',gap:16,fontSize:12}}>
                {[
                  {l:'Stars',v:repoInfo.stars?.toLocaleString(),c:T.orange},
                  {l:'Forks',v:repoInfo.forks?.toLocaleString(),c:T.purple},
                  {l:'Commits',v:commits.length,c:T.accent},
                  {l:'Branches',v:branches.length,c:T.green},
                  {l:'Contributors',v:contributors.length,c:T.pink},
                ].map(s=>(
                  <div key={s.l} style={{display:'flex',alignItems:'center',gap:5}}>
                    <span style={{color:s.c,fontWeight:700,fontSize:14}}>{s.v}</span>
                    <span style={{color:T.textMuted}}>{s.l}</span>
                  </div>
                ))}
              </div>
            </div>
          )}

          {/* Controls */}
          <div style={{display:'flex',justifyContent:'space-between',alignItems:'center',padding:'6px 20px',borderBottom:`1px solid ${T.border}`,background:T.surfaceAlt,gap:12,flexWrap:'wrap',flexShrink:0}}>
            <div style={{display:'flex',gap:4,flexWrap:'wrap'}}>
              <button onClick={()=>setBranchFilter('all')} style={{
                background:branchFilter==='all'?T.accent+'18':'transparent',border:`1px solid ${branchFilter==='all'?T.accent+'55':T.border}`,
                color:branchFilter==='all'?T.accent:T.textMuted,borderRadius:6,padding:'3px 10px',fontSize:12,cursor:'pointer',fontWeight:branchFilter==='all'?600:400,
              }}>All</button>
              {branches.map(b=>(
                <button key={b.name} onClick={()=>setBranchFilter(b.name)} style={{
                  background:branchFilter===b.name?(branchColors[b.name]||T.accent)+'18':'transparent',
                  border:`1px solid ${branchFilter===b.name?(branchColors[b.name]||T.accent)+'55':T.border}`,
                  color:branchFilter===b.name?(branchColors[b.name]||T.accent):T.textMuted,
                  borderRadius:6,padding:'3px 10px',fontSize:12,cursor:'pointer',fontWeight:branchFilter===b.name?600:400,
                }}>{b.name}</button>
              ))}
            </div>
            <div style={{display:'flex',gap:8,alignItems:'center'}}>
              <div style={{display:'flex',alignItems:'center',gap:6,background:T.bg,border:`1px solid ${T.border}`,borderRadius:6,padding:'0 8px'}}>
                <span style={{color:T.textDim,fontSize:12}}>🔍</span>
                <input value={searchTerm} onChange={e=>setSearchTerm(e.target.value)} placeholder="Search commits..."
                  style={{background:'none',border:'none',color:T.text,fontSize:12,outline:'none',padding:'5px 0',width:130}}/>
              </div>
              <div style={{display:'flex',background:T.bg,borderRadius:6,padding:2,border:`1px solid ${T.border}`}}>
                {['graph','list'].map(v=>(
                  <button key={v} onClick={()=>setView(v)} style={{
                    background:view===v?T.accent+'1a':'transparent',color:view===v?T.accent:T.textMuted,
                    border:'none',borderRadius:4,padding:'4px 12px',cursor:'pointer',fontSize:12,fontWeight:500,textTransform:'capitalize',
                  }}>{v}</button>
                ))}
              </div>
            </div>
          </div>

          {/* Main view */}
          <div style={{flex:1,overflow:'hidden'}}>
            {view==='graph'?(
              <CommitGraph commits={filteredCommits} branchColors={branchColors}
                selectedSha={selectedCommit?.sha} onSelect={setSelectedCommit}
                branchFilter={branchFilter} hoveredSha={hoveredSha} setHoveredSha={setHoveredSha}/>
            ):(
              <CommitList commits={filteredCommits} selectedSha={selectedCommit?.sha}
                onSelect={setSelectedCommit} branchColors={branchColors}/>
            )}
          </div>
        </div>
      )}

      {/* Empty state */}
      {!loading&&commits.length===0&&!error&&(
        <div style={{flex:1,display:'flex',flexDirection:'column',alignItems:'center',justifyContent:'center',gap:24,padding:40}}>
          <div style={{position:'relative'}}>
            <svg width="90" height="90" viewBox="0 0 24 24" fill="none" stroke={T.border} strokeWidth="1">
              <circle cx="6" cy="5" r="2"/><circle cx="18" cy="5" r="2"/><circle cx="12" cy="19" r="2"/>
              <line x1="6" y1="7" x2="12" y2="17"/><line x1="18" y1="7" x2="12" y2="17"/>
            </svg>
            <div style={{position:'absolute',top:-6,right:-10,width:22,height:22,background:T.accent,borderRadius:'50%',display:'flex',alignItems:'center',justifyContent:'center',animation:'pulse 2s infinite'}}>
              <span style={{fontSize:11}}>✦</span>
            </div>
            <style>{`@keyframes pulse{0%,100%{opacity:1;transform:scale(1)}50%{opacity:.6;transform:scale(.9)}}`}</style>
          </div>
          <div style={{textAlign:'center'}}>
            <h1 style={{fontSize:26,fontWeight:800,margin:'0 0 8px'}}>Visual<span style={{color:T.accent}}>Git</span> Client</h1>
            <p style={{color:T.textMuted,fontSize:14,maxWidth:420,margin:'0 auto',lineHeight:1.6}}>
              Explore any public GitHub repository. Visualize commit history as an interactive graph, browse branches, and inspect diffs.
            </p>
          </div>
          <div style={{display:'flex',gap:8,flexWrap:'wrap',justifyContent:'center'}}>
            {[{n:'facebook/react',d:'React.js'},{n:'vuejs/vue',d:'Vue.js'},{n:'denoland/deno',d:'Deno'},{n:'expressjs/express',d:'Express'}].map(r=>(
              <button key={r.n} onClick={()=>setUrl(`https://github.com/${r.n}`)} style={{
                background:T.surface,border:`1px solid ${T.border}`,borderRadius:8,padding:'10px 18px',
                color:T.text,cursor:'pointer',fontSize:13,textAlign:'left',
              }}>
                <div style={{fontWeight:600}}>{r.d}</div>
                <div style={{color:T.textDim,fontSize:11,marginTop:2}}>{r.n}</div>
              </button>
            ))}
          </div>
        </div>
      )}

      <DiffPanel commit={selectedCommit} owner={parsed?.owner} repo={parsed?.repo} token={token} onClose={()=>setSelectedCommit(null)}/>
    </div>
  );
}
APPEOF

# ─── README ───
cat > README.md << 'EOF'
# ⬡ VisualGit — Browser-Based Interactive Git Repository Explorer

Full-stack web app that visualizes any public GitHub repo's commit history as an interactive graph.

## Features
- Interactive D3.js vertical commit graph with zoom (+/- buttons), pan (grab cursor), hover tooltips, and click-to-glow
- Diff viewer with syntax-highlighted file patches
- Branch filtering, commit search, graph/list toggle
- Repository insights (stars, forks, contributors)
- GitHub token support for higher API rate limits

## Tech Stack
React 19 | D3.js v7 | Vite 8 | Express.js 5 | GitHub REST API v3

## Quick Start
```bash
npm install
# Terminal 1
cd server && npm run dev
# Terminal 2
cd client && npm run dev
```
Open http://localhost:5173

## Deploy to Railway
Push to GitHub → Connect to Railway → auto-deploys.
Add GITHUB_TOKEN env var for 5,000 req/hr.

## License
MIT
EOF

echo ""
echo "✅ All files created/updated!"
echo ""
echo "Next steps:"
echo "  1. npm install  (if first time)"
echo "  2. Terminal 1: cd server && npm run dev"
echo "  3. Terminal 2: cd client && npm run dev"
echo "  4. Open http://localhost:5173"