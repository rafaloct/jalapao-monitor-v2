/// <reference path="../pb_data/types.d.ts" />

// Adiciona `role` (select) à collection `users` — os papéis vêm da matriz de
// acesso aprovada (docs/security/ACCESS_MATRIX.md, ata da issue #13).
// O gate de papel do AuthService (PR #38) depende deste campo existir.
// Backfill: a conta gestor@jalapao.br vira `coordenador` (papel que aprova
// places na matriz — A(ter) T3).
migrate((app) => {
  const users = app.findCollectionByNameOrId("users");

  users.fields.add(new Field({
    name: "role",
    type: "select",
    required: false,
    maxSelect: 1,
    values: [
      "operador",
      "gerente",
      "coordenador",
      "pesquisador",
      "agencia_guia",
      "display_tv",
      "turista",
      "admin",
      "gestor", // legado: nome de tela, mantido para compat com o gate do app
    ],
  }));
  app.save(users);

  // Backfill: contas existentes sem papel ficam sem acesso gestor até
  // classificação. A conta operacional conhecida recebe `coordenador`.
  const known = {
    "gestor@jalapao.br": "coordenador",
  };
  for (const email in known) {
    try {
      const rec = app.findFirstRecordByData("users", "email", email);
      if (rec) {
        rec.set("role", known[email]);
        app.save(rec);
      }
    } catch (_) {
      // conta não existe nesta instalação — nada a fazer
    }
  }
}, (app) => {
  const users = app.findCollectionByNameOrId("users");
  users.fields.removeByName("role");
  app.save(users);
});
