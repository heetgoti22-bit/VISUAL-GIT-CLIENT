# ⬡ VisualGit — Browser-Based Interactive Git Repository Explorer

> A full-stack web application that transforms any public GitHub repository into an interactive, visual commit graph — explore branches, inspect diffs, and compare commits, all from your browser.

### **[🚀 Live Demo → web-production-0f401.up.railway.app](https://web-production-0f401.up.railway.app)**

---

## 🎯 What is VisualGit?

Every developer uses Git daily, but most interact with it through cryptic terminal commands. **VisualGit** brings Git history to life — turning abstract commit hashes and branch pointers into a navigable, interactive graph.

Paste any public GitHub repo URL and instantly see:
- The full **commit DAG** (Directed Acyclic Graph) rendered as an interactive visualization
- **Branch relationships** — how features diverge and merge back
- **File-level diffs** with syntax-highlighted additions and deletions
- **Side-by-side commit comparisons** showing exactly what changed between any two points in history

Think of it as an open-source, browser-based alternative to [GitKraken](https://www.gitkraken.com/) or [Sourcetree](https://www.sourcetreeapp.com/) — but with zero installation.

---

## ✨ Features

### 🔀 Interactive Commit Graph
- **D3.js-powered** vertical DAG visualization with branch-colored lanes
- **Zoom & Pan** — scroll to zoom, drag to pan (grab cursor), +/− controls
- **Hover tooltips** — mouse over any node to preview commit info
- **Click-to-glow** — selected commits highlight with an animated glow ring
- **Merge visualization** — cross-branch merges rendered as smooth Bézier curves

### 📝 Diff Viewer
- Click any commit to open a **slide-over diff panel**
- **File-by-file breakdown** with status badges: Added (A), Modified (M), Deleted (D), Renamed (R)
- **Syntax-highlighted patches** — green for additions, red for deletions, purple for chunk headers
- **Collapsible file sections** — expand only what you need
- **Stats summary** — total additions, deletions, and file count

### ⚖️ Commit Comparison
- Toggle **Compare Mode** to diff any two commits
- Select commit **A** and **B** from the graph or list view
- See **ahead/behind counts**, commit range, and full file-level diff
- Works across branches — compare a feature branch tip to main

### 📊 Repository Insights
- **Stars, forks, contributors, branch count** at a glance
- **Owner avatar and description** pulled from GitHub API
- **Branch filtering** — isolate any branch to focus the graph
- **Commit search** — filter by message, author name, or SHA hash

### 📱 Responsive Design
- Adapts to **desktop, tablet, and mobile** screens
- Branch pills collapse on small viewports
- Diff panels go full-width on mobile
- Touch-friendly zoom and pan on tablets

### 🎨 Visual Polish
- **Animated particle background** with grid lines and connecting nodes
- **Glassmorphism UI** with backdrop blur and translucent panels
- **Gradient accents** and smooth transitions throughout
- **Dark theme** optimized for extended use

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Client (React 19)                 │
│                                                      │
│  ┌─────────────┐  ┌────────────┐  ┌──────────────┐ │
│  │  D3.js v7   │  │  Commit    │  │   Compare    │ │
│  │  Commit     │  │  List +    │  │   Panel +    │ │
│  │  Graph      │  │  Search    │  │   Diff View  │ │
│  └─────────────┘  └────────────┘  └──────────────┘ │
│                                                      │
│           Vite 8 (Dev Server + Build)                │
└────────────────────────┬────────────────────────────┘
                         │ /api/*
┌────────────────────────▼────────────────────────────┐
│                  Server (Express 5)                  │
│                                                      │
│  ┌────────────────────────────────────────────────┐ │
│  │           GitHub API Proxy Layer                │ │
│  │                                                 │ │
│  │  GET /api/repo/:owner/:repo          Repo info  │ │
│  │  GET /api/repo/:owner/:repo/branches Branches   │ │
│  │  GET /api/repo/:owner/:repo/commits  Commits    │ │
│  │  GET /api/repo/:owner/:repo/commits/:sha  Diff  │ │
│  │  GET /api/repo/:owner/:repo/compare  Compare    │ │
│  │  GET /api/repo/:owner/:repo/tree/:sha File tree │ │
│  │  GET /api/repo/:owner/:repo/contributors  Users │ │
│  │  GET /api/rate-limit            Rate limit info  │ │
│  └────────────────────────────────────────────────┘ │
│                                                      │
│        + Static file serving (production)            │
└────────────────────────┬────────────────────────────┘
                         │
                ┌────────▼────────┐
                │  GitHub REST    │
                │    API v3       │
                └─────────────────┘
```

---

## 🛠️ Tech Stack

| Layer       | Technology        | Purpose                                              |
|-------------|-------------------|------------------------------------------------------|
| Frontend    | React 19          | Component-based UI with hooks for state management   |
| Visualization | D3.js v7       | SVG-based interactive commit graph with zoom/pan     |
| Bundler     | Vite 8            | Sub-second HMR in dev, optimized production builds   |
| Backend     | Express.js 5      | Lightweight API proxy with structured error handling |
| API         | GitHub REST v3    | Commits, branches, diffs, comparisons, contributors |
| Deployment  | Railway           | Auto-deploy from GitHub with zero configuration      |

---

## 🚀 Getting Started

### Prerequisites
- **Node.js** 18+ and **npm** 9+
- (Optional) [GitHub Personal Access Token](https://github.com/settings/tokens) for higher rate limits

### Local Development

```bash
# Clone
git clone https://github.com/heetgoti22-bit/visual-git-client.git
cd visual-git-client

# Install all dependencies (root + client + server)
npm install

# Start backend (Terminal 1)
cd server && npm run dev

# Start frontend (Terminal 2)
cd client && npm run dev
```

Open **http://localhost:5173** — the Vite dev server proxies API calls to Express on port 3001.

### Production Build

```bash
npm run build    # Builds the Vite client into client/dist/
npm start        # Express serves the built frontend + API
```

---

## 📁 Project Structure

```
visual-git-client/
├── client/                    # React frontend
│   ├── src/
│   │   ├── App.jsx            # Main app — graph, list, diff, compare
│   │   └── main.jsx           # Entry point with global styles
│   ├── index.html             # HTML shell
│   ├── vite.config.js         # Vite config with API proxy
│   └── package.json
├── server/
│   ├── server.js              # Express API — 8 GitHub proxy endpoints
│   └── package.json
├── package.json               # Root — orchestrates install, build, start
├── Procfile                   # Railway/Heroku process definition
├── .gitignore
├── .env.example               # Environment variable template
└── README.md
```

---

## 🌐 Deployment

### Railway (Recommended)

1. Push code to GitHub
2. Connect the repo at [railway.app](https://railway.app)
3. Add environment variable: `GITHUB_TOKEN` = your token
4. Railway auto-runs: `npm install` → `npm run build` → `npm start`
5. Get your public URL

### Other Platforms

Works on any platform that supports Node.js: **Render**, **Fly.io**, **Heroku**, **Vercel** (with serverless adapter), or **Docker**.

---

## 🔑 GitHub Token

Without a token, GitHub limits you to **60 API requests/hour**. With a token, you get **5,000/hour**.

1. Go to [github.com/settings/tokens](https://github.com/settings/tokens)
2. Generate a **Classic** token with `public_repo` scope
3. Either paste it in the app's 🔑 field, or set it as `GITHUB_TOKEN` env variable

---

## 🧠 Technical Highlights

**Git internals understanding** — The commit graph correctly represents Git's DAG structure, showing parent-child relationships, branch divergence, and merge points.

**D3.js mastery** — Custom SVG rendering with zoom/pan behaviors, animated hover states, Bézier curves for merge lines, and dynamic layout calculation.

**API design** — Clean proxy layer that normalizes GitHub's API responses, handles rate limiting gracefully, and supports optional authentication.

**Full-stack deployment** — Monorepo with unified build pipeline: Vite builds the client, Express serves it alongside the API, Railway deploys everything from one `npm start`.

---

## 🗺️ Roadmap

- [ ] AI-powered commit message summarization
- [ ] File tree explorer with syntax-highlighted code viewer
- [ ] GitLab and Bitbucket support
- [ ] Dark/light theme toggle
- [ ] Export graph as SVG/PNG
- [ ] Keyboard shortcuts for navigation
- [ ] Pull request visualization

---

## 📄 License

MIT — free for personal and commercial use.

---

**Built by [Heet Goti](https://github.com/heetgoti22-bit)**