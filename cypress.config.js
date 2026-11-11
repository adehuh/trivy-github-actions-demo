// Cypress config. Runs inside the cypress/included Docker image (no npm install needed):
//   docker run --rm --network host -v "$PWD:/e2e" -w /e2e cypress/included:16.2.0 --spec "cypress/e2e/p0/**/*.cy.js"
// baseUrl is overridden in CI with CYPRESS_baseUrl (staging URL in real life).
module.exports = {
  e2e: {
    baseUrl: "http://localhost:8080",
    specPattern: "cypress/e2e/**/*.cy.js",
    supportFile: false,
  },
  video: false,
  screenshotOnRunFailure: true,
  retries: { runMode: 1, openMode: 0 }, // one retry in CI against flaky networks
};
