import { HttpService } from '@nestjs/axios';
import { Injectable } from '@nestjs/common';
import { firstValueFrom } from 'rxjs';

interface PaymentRequest {
  amount: number;
  slow: boolean;
}

@Injectable()
export class PaymentsService {
  constructor(private readonly http: HttpService) {}

  async authorize(request: PaymentRequest) {
    const delay = request.slow ? 2 : 1;

    await firstValueFrom(
      this.http.get(`/delay/${delay}`, {
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
}
