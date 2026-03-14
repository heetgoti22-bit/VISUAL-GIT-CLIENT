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
