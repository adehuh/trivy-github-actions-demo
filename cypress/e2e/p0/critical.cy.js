// [E2E P0] blocking: if any of these fail, the pipeline stops before DAST / production.
// The demo API only has /healthz and /products, so P0 tests the API with cy.request().
describe("[E2E P0] critical flows", () => {
  it("service is healthy", () => {
    cy.request("/healthz").its("body").should("deep.equal", { status: "ok" });
  });

  it("catalog returns products with price and stock (JSON)", () => {
    cy.request("/products").then((res) => {
      expect(res.status).to.eq(200);
      expect(res.headers["content-type"]).to.include("application/json");
      expect(res.body.apple).to.include({ price: 10000, stock: 5 });
    });
  });

  it("inventory: out-of-stock product shows stock 0", () => {
    cy.request("/products").its("body.mango.stock").should("eq", 0);
  });

  it("unknown route returns 404 JSON (no stack trace leaked)", () => {
    cy.request({ url: "/admin", failOnStatusCode: false }).then((res) => {
      expect(res.status).to.eq(404);
      expect(res.body).to.deep.equal({ error: "not found" });
    });
  });

  // SAMPLE for a real shop UI (login -> cart -> checkout with SANDBOX payment):
  // it("customer can check out", () => {
  //   cy.visit("/login");
  //   cy.get("[data-cy=email]").type(Cypress.env("E2E_USER"));        // test account from CI secret
  //   cy.get("[data-cy=password]").type(Cypress.env("E2E_PASSWORD"), { log: false });
  //   cy.get("[data-cy=submit]").click();
  //   cy.visit("/products/apple");
  //   cy.get("[data-cy=add-to-cart]").click();
  //   cy.get("[data-cy=cart-count]").should("have.text", "1");
  //   cy.get("[data-cy=checkout]").click();
  //   cy.get("[data-cy=card]").type("4242424242424242");                // payment provider TEST card
  //   cy.get("[data-cy=pay]").click();
  //   cy.contains("Order confirmed").should("be.visible");
  // });
});
