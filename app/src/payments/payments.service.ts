import { HttpService } from '@nestjs/axios';
import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { firstValueFrom } from 'rxjs';

interface PaymentRequest {
  amount: number;
  slow: boolean;
}

@Injectable()
export class PaymentsService {
  constructor(
    private readonly http: HttpService,
    private readonly config: ConfigService,
  ) {}

  async authorize(request: PaymentRequest) {
    const delay = request.slow ? 2 : 1;
    const shouldFail = Math.random() < this.mock5xxRate();
    const path = shouldFail ? '/status/500' : `/delay/${delay}`;

    await firstValueFrom(
      this.http.get(path, {
        headers: {
          'x-lab-payment-amount': String(request.amount),
        },
      }),
    );

    return {
      id: `pay_${Date.now()}`,
      amount: request.amount,
      provider: this.http.axiosRef.defaults.baseURL,
    };
  }

  private mock5xxRate() {
    const rawRate = this.config.get<string>('PAYMENTS_MOCK_5XX_RATE');
    const rate = Number(rawRate);

    if (!Number.isFinite(rate) || rate < 0 || rate > 1) {
      return 0;
    }

    return rate;
  }
}
