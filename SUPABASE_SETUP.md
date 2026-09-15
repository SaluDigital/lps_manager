# Setup do Supabase

1. Abra o projeto no Supabase e rode `db/supabase_schema.sql` no SQL Editor.
2. Em `Authentication > Users`, crie usuarios com os mesmos e-mails cadastrados na tabela `profiles`.
3. Copie `Project URL` e `anon public key` em `Project Settings > API`.
4. Substitua no topo do `index.html`:

```html
window.SUPABASE_URL = 'COLE_AQUI_A_URL_DO_SEU_PROJETO_SUPABASE';
window.SUPABASE_ANON_KEY = 'COLE_AQUI_A_CHAVE_ANON_PUBLIC_DO_SUPABASE';
```

## Permissoes

- `admin`: cria, edita e remove clientes e landing pages; gerencia perfis.
- `midia`: visualiza clientes/LPs e pode alterar status de landing pages.

## Observacao sobre usuarios

O app grava perfis em `profiles`. A senha real pertence ao Supabase Auth, por isso o login deve existir em `Authentication > Users`. Isso evita expor chave de servico no navegador.
