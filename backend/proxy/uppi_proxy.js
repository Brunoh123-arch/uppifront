/**
 * Uppi Local Reverse Proxy (Gateway de Conexão App <-> Supabase)
 * 
 * Intercepta chamadas do app Uppi e encaminha para o backend Supabase:
 * - tc.mobile.yandex.net (startup, routestats, ordercommit, orderstate, pix)
 * - passport.yandex.ru (login telefônico, SMS OTP com código de teste 1234)
 */
const http = require('http');
const https = require('https');
const url = require('url');

const SUPABASE_HOST = process.env.SUPABASE_HOST || 'bhyqkrnfdbrewcwaiomh.supabase.co';
const PORT = process.env.PORT || 8080;

// Mapeamento das rotas do app para as Edge Functions do Supabase
const ROUTE_MAP = {
  // 1. Handshake & Inicialização
  '/4.0/startup': '/functions/v1/startup',
  '/startup': '/functions/v1/startup',
  
  // 2. Rotas e Tarifas
  '/4.0/routestats': '/functions/v1/routestats',
  '/routestats': '/functions/v1/routestats',
  
  // 3. Pedidos e Corridas
  '/4.0/ordercommit': '/functions/v1/ordercommit',
  '/ordercommit': '/functions/v1/ordercommit',
  
  // 4. Rastreamento e Status
  '/4.0/orderstate': '/functions/v1/orderstate',
  '/orderstate': '/functions/v1/orderstate',
  
  // 5. Pagamentos Pix
  '/4.0/pix-payment': '/functions/v1/pix-payment',
  '/pix-payment': '/functions/v1/pix-payment',

  // 6. Autenticação & SMS OTP (Passaporte)
  '/auth/phone': '/functions/v1/auth-phone',
  '/auth/phone/confirm': '/functions/v1/auth-phone',
  '/passport/phone': '/functions/v1/auth-phone',
  '/domik/phone': '/functions/v1/auth-phone'
};

const server = http.createServer((req, res) => {
  const parsedUrl = url.parse(req.url, true);
  const targetPath = ROUTE_MAP[parsedUrl.pathname] || `/functions/v1${parsedUrl.pathname}`;
  
  console.log(`[UPPI PROXY] ${req.method} ${parsedUrl.pathname} -> https://${SUPABASE_HOST}${targetPath}`);

  let body = [];
  req.on('data', chunk => body.push(chunk));
  req.on('end', () => {
    let postData = Buffer.concat(body);

    // Se for rota de autenticação da Yandex, adaptar payload
    if (parsedUrl.pathname.includes('phone') || parsedUrl.pathname.includes('auth')) {
      try {
        const jsonBody = JSON.parse(postData.toString());
        if (!jsonBody.action) {
          jsonBody.action = jsonBody.code ? 'verify_code' : 'request_code';
        }
        postData = Buffer.from(JSON.stringify(jsonBody));
      } catch (e) {}
    }

    const options = {
      hostname: SUPABASE_HOST,
      port: 443,
      path: targetPath,
      method: req.method,
      headers: {
        'Content-Type': req.headers['content-type'] || 'application/json',
        'Content-Length': postData.length,
        'User-Agent': req.headers['user-agent'] || 'Uppi-Android/5.98.5'
      }
    };

    const sReq = https.request(options, (sRes) => {
      res.writeHead(sRes.statusCode, {
        ...sRes.headers,
        'Access-Control-Allow-Origin': '*',
        'X-Powered-By': 'Uppi-Proxy-Supabase'
      });
      sRes.pipe(res);
    });

    sReq.on('error', (err) => {
      console.error('[UPPI PROXY ERROR]', err.message);
      res.writeHead(502, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: 'Supabase Gateway Error', message: err.message }));
    });

    sReq.write(postData);
    sReq.end();
  });
});

server.listen(PORT, () => {
  console.log(`========================================================`);
  console.log(`🚀 UPPI GATEWAY PROXY ATIVO NA PORTA ${PORT}`);
  console.log(`Supabase Conectado: https://${SUPABASE_HOST}`);
  console.log(`--------------------------------------------------------`);
  console.log(`Rotas Mapeadas:`);
  Object.entries(ROUTE_MAP).forEach(([k, v]) => console.log(`  ${k.padEnd(25)} -> ${v}`));
  console.log(`========================================================`);
});
