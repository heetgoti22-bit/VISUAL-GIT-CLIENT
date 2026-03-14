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

app.get('/api/repo/:owner/:repo/compare', async (req, res) => {
  try {
    const { owner, repo } = req.params;
    const base = req.query.base;
    const head = req.query.head;
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
