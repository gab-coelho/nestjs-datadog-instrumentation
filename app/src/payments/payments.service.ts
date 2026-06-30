import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

interface PaymentRequest {
  amount: number;
  slow: boolean;
}

@Injectable()
export class PaymentsService {
  private readonly log = new Logger(PaymentsService.name);
  private readonly baseUrl = process.env.PAYMENTS_URL ?? 'https://httpbun.com';

  async authorize(request: PaymentRequest) {
    const delay = request.slow ? 2 : 1;

    try {
      await axios.get(`${this.baseUrl}/delay/${delay}`, {
        timeout: 5000,
        headers: {
          'x-lab-payment-amount': String(request.amount),
        },
      });
    } catch (error) {
      this.log.warn(`mock payment call failed: ${(error as Error).message}`);
    }

    return {
      id: `pay_${Date.now()}`,
      amount: request.amount,
      provider: this.baseUrl,
    };
  }
}
