const express = require('express');

const app = express();
app.use(express.json());

// in-memory store is enough for a pipeline demo
const notes = [
  { id: 1, title: 'Session 17', body: 'DevSecOps pipeline with security gates' },
  { id: 2, title: 'Session 17', body: 'DevSecOps pipeline' }
];

app.get('/', (req, res) => {
  res.json({
    service: 'campus-secure-api',
    version: process.env.APP_VERSION || 'dev',
    student: 'Siddhant Prasad (24BCS10255)',
    message: 'Deployed by the GitHub Actions CI/CD pipeline'
  });
});

app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

app.get('/api/notes', (req, res) => res.json(notes));

app.get('/api/notes/:id', (req, res) => {
  const note = notes.find(n => n.id === Number(req.params.id));
  if (!note) return res.status(404).json({ error: 'note not found' });
  res.json(note);
});

app.post('/api/notes', (req, res) => {
  const { title, body } = req.body || {};
  if (!title) return res.status(400).json({ error: 'title is required' });
  const note = { id: notes.length + 1, title, body: body || '' };
  notes.push(note);
  res.status(201).json(note);
});

module.exports = app;
