import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    steady: {
      executor: 'constant-vus',
      vus: Number(__ENV.VUS || 5),
      duration: __ENV.DURATION || '2m',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.25'],
    http_req_duration: ['p(95)<3500'],
  },
};

const target = (__ENV.TARGET_URL || 'http://localhost:3000').replace(/\/$/, '');

function ok(res, label) {
  check(res, {
    [`${label} status is expected`]: (r) => r.status >= 200 && r.status < 500,
  });
}

export default function () {
  const pick = Math.random();

  if (pick < 0.15) {
    ok(http.get(`${target}/health`), 'health');
  } else if (pick < 0.45) {
    ok(http.get(`${target}/orders`), 'list orders');
  } else if (pick < 0.65) {
    const id = Math.floor(Math.random() * 3) + 1;
    ok(http.get(`${target}/orders/${id}`), 'get order');
  } else if (pick < 0.8) {
    ok(
      http.post(
        `${target}/orders`,
        JSON.stringify({
          item: `load-test-item-${__VU}`,
          quantity: 1,
          amount: 12.5,
        }),
        { headers: { 'content-type': 'application/json' } },
      ),
      'create order',
    );
  } else if (pick < 0.9) {
    ok(http.get(`${target}/orders/9999`), 'missing order');
  } else {
    ok(
      http.post(
        `${target}/orders`,
        JSON.stringify({
          item: 'slow-payment-item',
          quantity: 1,
          amount: 19.99,
          slowPayment: true,
        }),
        { headers: { 'content-type': 'application/json' } },
      ),
      'slow create order',
    );
  }

  sleep(Math.random() * 0.8 + 0.2);
}
