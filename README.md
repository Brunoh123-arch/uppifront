# 🚗 Uppi - Plataforma Brasileira de Mobilidade e Entregas (v2.0)

Repositório Monorepo completo da plataforma **Uppi**, composto pela aplicação oficial multiplataforma (**Flutter 3.44**) e pela infraestrutura em nuvem no **Supabase** (Postgres 17 + PostGIS + Edge Functions + Liquidação Pix).

---

## 📁 Estrutura do Monorepo

```text
Uppi/
├── frontend/               # Aplicativo Oficial Multiplataforma (Flutter / Dart)
│   ├── lib/
│   │   ├── main.dart       # Ponto de entrada com tema Dark/Amarelo Uppi
│   │   ├── core/           # Configurações de API, tema e cliente HTTP Supabase
│   │   ├── models/         # Modelos de dados (Usuário, Corrida, Tarifas)
│   │   └── screens/
│   │       ├── auth_screen.dart             # Login com celular (+55) e bypass 1234
│   │       ├── passenger/                   # Fluxo do Passageiro
│   │       │   ├── passenger_home_screen.dart # Cotação Pop, Comfort, Moto, Entrega
│   │       │   ├── pix_payment_modal.dart   # QR Code Pix e Copia e Cola instantâneo
│   │       │   └── ride_tracking_screen.dart# Telemetria e rastreamento da corrida
│   │       └── driver/                      # Fluxo do Motorista
│   │           ├── driver_home_screen.dart  # Chave Online/Offline com GPS em tempo real
│   │           ├── driver_trip_screen.dart  # Ciclo da viagem (Chegada, Início, Fim)
│   │           └── driver_wallet_screen.dart# Extrato de repasses (85%) e saque Pix
│   └── test/               # Suíte de testes unitários e de widgets
│
├── backend/                # Infraestrutura e Servidores em Nuvem (Supabase)
│   ├── database/
│   │   └── schema.sql      # Schema Postgres com PostGIS, GIST, RLS e Tarifas
│   ├── functions/          # 8 Edge Functions Deno/TypeScript ativas
│   │   ├── auth-phone/     # Login telefônico com código fixo 1234
│   │   ├── startup/        # Handshake regional (BRL, +55, SP, SOS)
│   │   ├── routestats/     # Cálculo viário, ETA e cotação das 4 categorias
│   │   ├── ordercommit/    # Criação do pedido com geração de Pix automático
│   │   ├── orderstate/     # Consulta de telemetria da corrida e motorista
│   │   ├── pix-payment/    # Emissão de Pix Copia e Cola e QR Code
│   │   ├── driver-action/  # Ações do motorista (GPS, aceite, chegada, repasse 85%)
│   │   └── pix-webhook/    # Webhook bancário de liquidação automática do Pix
│   ├── proxy/
│   │   └── uppi_proxy.js   # Gateway Proxy Node.js
│   └── tests/
│       └── test_full_ecosystem.js # Teste automatizado E2E de 11 passos do ecossistema
│
├── .gitignore              # Proteção contra binários pesados (>100MB) para o GitHub
└── README.md               # Esta documentação
```

---

## ⚡ 1. Backend Supabase (`Uppi Back`)

O backend está homologado na região **São Paulo (`sa-east-1`)**:

* **Host:** `https://bhyqkrnfdbrewcwaiomh.supabase.co`
* **Banco de Dados:** Postgres 17.11 com extensão `postgis` e índices espaciais `GIST`.
* **Segurança:** Row Level Security (RLS) ativo em todas as tabelas.

### Tarifas Oficiais (São Paulo):
1. **Uppi Pop:** Base R$ 5,50 | R$ 2,10/km | R$ 0,35/min (Mínimo R$ 9,00)
2. **Uppi Comfort:** Base R$ 8,00 | R$ 2,80/km | R$ 0,45/min (Mínimo R$ 14,00)
3. **Uppi Moto:** Base R$ 3,50 | R$ 1,40/km | R$ 0,25/min (Mínimo R$ 7,00)
4. **Uppi Entrega:** Base R$ 5,00 | R$ 1,80/km | R$ 0,30/min (Mínimo R$ 8,50)

### Divisão Financeira da Plataforma:
* **Repasse ao Motorista:** **85%** de todo o valor bruto da corrida.
* **Taxa da Plataforma Uppi:** **15%** para manutenção e infraestrutura.

---

## 📱 2. Como Rodar o Aplicativo (Frontend)

O aplicativo foi construído em **Flutter 3.44 (Dart 3.12)**:

```bash
# 1. Entrar na pasta do frontend
cd frontend

# 2. Instalar dependências
flutter pub get

# 3. Rodar análise estática
flutter analyze

# 4. Executar o app no emulador ou dispositivo físico
flutter run
```

---

## 🧪 3. Como Executar o Teste E2E do Ecossistema

O teste simula o fluxo completo de 11 passos (Passageiro faz login $\rightarrow$ Motorista conecta $\rightarrow$ Corrida solicitada $\rightarrow$ Pix pago $\rightarrow$ Motorista aceita e finaliza $\rightarrow$ Saldo de 85% creditado):

```bash
node backend/tests/test_full_ecosystem.js
```

---

## 🚀 4. Como Subir no GitHub

Na pasta raiz do projeto, execute no terminal:

```bash
# 1. Verificar o status dos arquivos
git status

# 2. Adicionar as alterações
git add .

# 3. Criar o commit da versão oficial
git commit -m "feat(core): implement fullstack monorepo Uppi 2.0 with Flutter frontend and Supabase backend"

# 4. Enviar para o repositório remoto
git push origin main
```
