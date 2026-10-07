const app = require('./app');

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`campus-notes-api listening on port ${port}`);
});
