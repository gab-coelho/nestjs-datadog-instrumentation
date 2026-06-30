import { HttpService } from '@nestjs/axios';
import { Injectable, Logger } from '@nestjs/common';
import { firstValueFrom } from 'rxjs';

interface PaymentRequest {
  amount: number;
  slow: boolean;
}

@Injectable()
export class PaymentsService {
  private readonly log = new Logger(PaymentsService.name);
  private readonly baseUrl: string;

  constructor(private readonly http: HttpService) {
    this.baseUrl = this.http.axiosRef.defaults.baseURL ?? 'https://httpbun.com';
  }

  async authorize(request: PaymentRequest) {
    const delay = request.slow ? 2 : 1;

    try {
      await firstValueFrom(this.http.get(`/delay/${delay}`, {
        headers: {
          'x-lab-payment-amount': String(request.amount),
        },
      }));
    } catch (error) {
      // The lab intentionally continues when the mock provider fails, so order flow still produces traces.
      const message = error instanceof Error ? error.message : String(error);
      this.log.warn(`mock payment call failed: ${message}`);
    }

    return {
      id: `pay_${Date.now()}`,
      amount: request.amount,
      provider: this.baseUrl,
    };
  }
}
