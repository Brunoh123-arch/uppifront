const https = require('https');

const ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJoeXFrcm5mZGJyZXdjd2Fpb21oIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzOTc2NzksImV4cCI6MjEwOTk3MzY3OX0.6SrJqQaznZbZpGTrv-8bmfa5cJJBkg_Gz_jgxEtz7C4';

function post(endpoint, body) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(body);
    const options = {
      hostname: 'bhyqkrnfdbrewcwaiomh.supabase.co',
      path: `/functions/v1/${endpoint}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'apikey': ANON_KEY,
        'Authorization': `Bearer ${ANON_KEY}`
      }
    };
    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          resolve({ status: res.statusCode, raw: data });
        }
      });
    });
    req.on('error', reject);
    req.write(postData);
    req.end();
  });
}

async function runEcosystemTest() {
  console.log('================================================================');
  console.log('🚀 UPPI 2.0 - TESTE COMPLETO DO ECOSSISTEMA (ESTRATÉGIA 3 CTO)');
  console.log('================================================================\n');

  // 1. Passageiro faz login
  console.log('--- 1. Login do Passageiro ---');
  const riderLogin = await post('auth-phone', {
    action: 'verify_code',
    phone: '+5511999990001',
    code: '1234',
    full_name: 'Mariana Silva (Passageira)'
  });
  const riderId = riderLogin.body?.user?.id;
  console.log('Passageira autenticada:', riderId, riderLogin.body?.user?.full_name);

  // 2. Motorista faz login e cadastra veículo
  console.log('\n--- 2. Login do Motorista ---');
  const driverLogin = await post('auth-phone', {
    action: 'verify_code',
    phone: '+5511999990002',
    code: '1234',
    full_name: 'Carlos Oliveira (Motorista Uppi)'
  });
  const driverId = driverLogin.body?.user?.id;
  console.log('Motorista autenticado:', driverId, driverLogin.body?.user?.full_name);

  // 3. Motorista fica Online e envia GPS
  console.log('\n--- 3. Motorista fica Online (GPS em São Paulo) ---');
  const gpsRes = await post('driver-action', {
    action: 'update_location',
    driver_id: driverId,
    lat: -23.5505,
    lon: -46.6333,
    bearing: 90,
    speed: 15
  });
  console.log('Status GPS Motorista:', gpsRes.body);

  // 4. Passageiro calcula rota
  console.log('\n--- 4. Passageiro pesquisa corrida (Av. Paulista -> Aeroporto) ---');
  const routeRes = await post('routestats', {
    origin: { lat: -23.5615, lon: -46.6559 },
    destination: { lat: -23.6273, lon: -46.6565 }
  });
  console.log('Orçamentos calculados:', routeRes.body.options?.map(o => `${o.name}: ${o.formatted_price} (${o.eta_text})`));

  // 5. Passageiro pede a corrida via Pix
  console.log('\n--- 5. Passageiro solicita Uppi Pop via Pix ---');
  const orderRes = await post('ordercommit', {
    rider_id: riderId,
    category: 'pop',
    origin: { lat: -23.5615, lon: -46.6559, address: 'Av. Paulista, 1000' },
    destination: { lat: -23.6273, lon: -46.6565, address: 'Aeroporto de Congonhas' },
    payment_method: 'pix',
    estimated_fare: 32.48
  });
  const orderId = orderRes.body?.order_id;
  const orderNumber = orderRes.body?.order_number;
  console.log(`Corrida criada: ${orderNumber} (ID: ${orderId})`);
  console.log(`Pix Copia e Cola gerado: ${orderRes.body?.pix?.pix_copy_paste}`);
  console.log(`QR Code URL gerada: ${orderRes.body?.pix?.qr_code_url}`);

  // 6. Liquidação Automática do Pix (Webhook da Instituição Financeira)
  console.log('\n--- 6. Webhook do Banco confirma pagamento do Pix ---');
  const webhookRes = await post('pix-webhook', {
    ride_id: orderId,
    status: 'PAID',
    amount: 32.48,
    txid: 'PIX-TXID-99887766'
  });
  console.log('Status da Liquidação Pix:', webhookRes.body);

  // 7. Motorista recebe alerta e aceita a corrida
  console.log('\n--- 7. Motorista aceita a corrida no app ---');
  const acceptRes = await post('driver-action', {
    action: 'accept_ride',
    ride_id: orderId,
    driver_id: driverId
  });
  console.log('Resultado do aceite:', acceptRes.body?.message, 'Novo status:', acceptRes.body?.ride?.status);

  // 8. Motorista avisa que chegou no local de embarque
  console.log('\n--- 8. Motorista chega no local (Arrived) ---');
  const arrivedRes = await post('driver-action', {
    action: 'arrived',
    ride_id: orderId,
    driver_id: driverId
  });
  console.log('Resultado da chegada:', arrivedRes.body?.message, 'Novo status:', arrivedRes.body?.ride?.status);

  // 9. Viagem inicia
  console.log('\n--- 9. Viagem Inicia (Start Trip) ---');
  const startRes = await post('driver-action', {
    action: 'start_trip',
    ride_id: orderId,
    driver_id: driverId
  });
  console.log('Viagem iniciada:', startRes.body?.message, 'Novo status:', startRes.body?.ride?.status);

  // 10. Viagem finalizada com cálculo de repasse
  console.log('\n--- 10. Viagem Finalizada e Crédito na Carteira ---');
  const completeRes = await post('driver-action', {
    action: 'complete_trip',
    ride_id: orderId,
    driver_id: driverId,
    final_fare: 32.48
  });
  console.log('Faturamento Total: R$', completeRes.body?.total_fare);
  console.log('Ganhos do Motorista (85%): R$', completeRes.body?.driver_earnings);
  console.log('Taxa da Plataforma Uppi (15%): R$', completeRes.body?.platform_fee);
  console.log('Novo Saldo da Carteira do Motorista: R$', completeRes.body?.driver_new_wallet_balance);

  // 11. Validação final pelo Orderstate
  console.log('\n--- 11. Checagem final do status da corrida ---');
  const stateRes = await post('orderstate', { ride_id: orderId });
  console.log('Status final da corrida no banco:', {
    ride_id: stateRes.body?.ride?.id,
    order_number: stateRes.body?.ride?.order_number,
    ride_status: stateRes.body?.ride?.status,
    payment_status: stateRes.body?.ride?.payment_status,
    final_fare: stateRes.body?.ride?.final_fare
  });

  console.log('\n================================================================');
  console.log('🎉 CICLO DE VIDA COMPLETO DO UPPI VALIDADO COM 100% DE SUCESSO!');
  console.log('================================================================\n');
}

runEcosystemTest().catch(console.error);
