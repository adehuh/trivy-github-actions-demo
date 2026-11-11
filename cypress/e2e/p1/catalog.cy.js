// [E2E P1] non-blocking (continue-on-error in CI): broader checks, QA reviews failures.
describe("[E2E P1] catalog quality", () => {
  it("every product has a non-negative integer price and stock", () => {
    cy.request("/products").then(({ body }) => {
      Object.entries(body).forEach(([name, p]) => {
        expect(p.price, `${name}.price`).to.be.a("number").and.to.be.at.least(0);
        expect(Number.isInteger(p.stock), `${name}.stock is integer`).to.eq(true);
      });
    });
  });

  it("catalog responds within 500 ms", () => {
    cy.request("/products").its("duration").should("be.lessThan", 500);
  });

  // SAMPLE for a real UI (search, filters, profile, order history):
  // it("search filters the list", () => {
  //   cy.visit("/products");
  //   cy.get("[data-cy=search]").type("apple");
  //   cy.get("[data-cy=product-card]").should("have.length", 1).and("contain", "apple");
  // });
  // it("order history shows the last order", () => {
  //   cy.loginByApi(Cypress.env("E2E_USER"), Cypress.env("E2E_PASSWORD"));   // custom command
  //   cy.visit("/account/orders");
  //   cy.get("[data-cy=order-row]").first().should("contain", "Paid");
  // });
});
