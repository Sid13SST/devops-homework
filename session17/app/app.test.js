const request = require('supertest');
const app = require('./app');

describe('campus-secure-api', () => {
  test('GET / returns service metadata', async () => {
    const res = await request(app).get('/');
    expect(res.statusCode).toBe(200);
    expect(res.body.service).toBe('campus-secure-api');
  });

  test('GET /health returns ok', async () => {
    const res = await request(app).get('/health');
    expect(res.statusCode).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  test('GET /api/notes returns a list', async () => {
    const res = await request(app).get('/api/notes');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body.length).toBeGreaterThan(0);
  });

  test('GET /api/notes/:id returns one note', async () => {
    const res = await request(app).get('/api/notes/1');
    expect(res.statusCode).toBe(200);
    expect(res.body.id).toBe(1);
  });

  test('GET /api/notes/:id returns 404 for an unknown id', async () => {
    const res = await request(app).get('/api/notes/9999');
    expect(res.statusCode).toBe(404);
  });

  test('POST /api/notes creates a note', async () => {
    const res = await request(app).post('/api/notes').send({ title: 'New', body: 'Created in CI' });
    expect(res.statusCode).toBe(201);
    expect(res.body.title).toBe('New');
  });

  test('POST /api/notes rejects a missing title', async () => {
    const res = await request(app).post('/api/notes').send({ body: 'no title' });
    expect(res.statusCode).toBe(400);
  });
});
