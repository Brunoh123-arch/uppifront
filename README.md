# 🚗 Uppi - Plataforma Brasileira de Mobilidade e Entregas

Repositório Fullstack completo da plataforma **Uppi**, composto pelo aplicativo Android corporativo de mobilidade urbana e pela infraestrutura de backend em nuvem no **Supabase** com Postgres e extensão espacial PostGIS.

---

## 📁 Estrutura do Repositório

```text
Uppi/
├── projeto_descompilado/   # Código-fonte e recursos do Aplicativo Android
│   ├── AndroidManifest.xml # Manifesto com 108 activities e permissões
│   ├── res/                # Mais de 2.800 layouts XML, ícones e strings PT-BR
│   ├── assets/             # DivKit Server-Driven UI e módulos Flutter
│   └── lib/arm64-v8a/      # Bibliotecas nativas C++ (MapKit, WebRTC, RNNoise)
│
├── backend/                # Infraestrutura e Código de Servidor
│   ├── database/           # Modelagem de dados Postgres
│   │   └── schema.sql      # Tabelas, PostGIS, GIST, RLS e Tarifas Brasileiras
│   ├── functions/          # Edge Functions Serverless (TypeScript / Deno)
│   │   ├── auth-phone/     # Login telefônico com código fixo 1234 (sem SMS russo)
│   │   ├── startup/        # Handshake regional (BRL, +55, SP, SOS)
│   │   ├── routestats/     # Cálculo viário, ETA e cotação Pop/Comfort/Moto
│   │   ├── ordercommit/    # Criação de corrida e disparo do Pix instantâneo
│   │   ├── orderstate/     # Rastreamento de corrida, motorista e telemetria
│   │   └── pix-payment/    # Emissão de Pix Copia e Cola e QR Code Banco Central
│   └── proxy/              # Servidor Proxy de Redirecionamento Local
│       └── uppi_proxy.js   # Ponte de tráfego app -> Supabase Edge Functions
│
├── .gitignore              # Filtros de segurança e exclusão de binários (>100MB)
└── README.md               # Documentação técnica do projeto
```

---

## ⚡ 1. Backend Supabase (`Uppi Back`)

O backend está homologado na região **São Paulo (`sa-east-1`)**:

* **Host:** `https://bhyqkrnfdbrewcwaiomh.supabase.co`
* **Banco de Dados:** Postgres 17.11 com extensão `postgis`.
* **Segurança:** Row Level Security (RLS) ativo em todas as tabelas.

### Categorias e Tarifas Brasileiras:
1. **Uppi Pop:** Base R$ 5,50 | R$ 2,10/km | R$ 0,35/min (Mínimo R$ 9,00)
2. **Uppi Comfort:** Base R$ 8,00 | R$ 2,80/km | R$ 0,45/min (Mínimo R$ 14,00)
3. **Uppi Moto:** Base R$ 3,50 | R$ 1,40/km | R$ 0,25/min (Mínimo R$ 7,00)
4. **Uppi Entrega:** Base R$ 5,00 | R$ 1,80/km | R$ 0,30/min (Mínimo R$ 8,50)

### Endpoints Serverless (Edge Functions):
* `POST /functions/v1/auth-phone`: Login telefônico instantâneo com código universal de teste `1234`.
* `POST /functions/v1/startup`: Inicialização do app, coordenadas centrais de São Paulo e suporte.
* `POST /functions/v1/routestats`: Estimativa de distância em rota, tempo de trajeto e preços.
* `POST /functions/v1/ordercommit`: Criação do pedido com geração de Pix automático no ato.
* `POST /functions/v1/orderstate`: Polling do status da corrida, motorista e carro.
* `POST /functions/v1/pix-payment`: Geração de payload Pix EMV oficial com QR Code.

---

## 📱 2. Aplicativo Android (Uppi Client)

* **Design e Telas:** Layouts 100% nativos em XML (`res/layout/`) com alta fluidez (60/120 FPS).
* **Localização Total PT-BR:** Idioma padrão em Português do Brasil, sem termos arcaicos europeus ou resquícios em cirílico.
* **Pagamento Instantâneo Pix:** O passageiro não precisa vincular chave bancária. O app gera o código Copia e Cola e o QR Code direto na finalização.
* **Segurança Integrada:** Central de Emergência configurada para os números brasileiros (Polícia Militar `190`, SAMU `192`, Bombeiros `193`).
* **Chamadas e Chat:** Chat interno em tempo real e suporte a ligações VoIP criptografadas via WebRTC (`libjingle_peerconnection_so.so`).

---

## 🚀 3. Como Subir no GitHub

Na pasta raiz do projeto, execute no terminal:

```bash
# 1. Inicializar o repositório Git
git init

# 2. Adicionar todos os arquivos (o .gitignore protegerá contra arquivos >100MB)
git add .

# 3. Criar o commit inicial
git commit -m "feat: initial commit - Uppi complete app and Supabase backend"

# 4. Vincular ao seu repositório remoto no GitHub
git branch -M main
git remote add origin https://github.com/SEU_USUARIO/SEU_REPOSITORIO.git

# 5. Enviar para o GitHub
git push -u origin main
```

---

## 🛠️ 4. Como Rodar o Proxy Local

Para testar o aplicativo conectando diretamente no backend Supabase:

```bash
cd backend/proxy
node uppi_proxy.js
```

O proxy escutará na porta `8080` e encaminhará todas as requisições de mobilidade para o Supabase `Uppi Back`.
